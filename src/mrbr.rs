// mrbr.rs

/* Magic Ring Buffer Implementation */

#![allow(warnings)]

use std::sync::atomic::{AtomicUsize, Ordering};
use std::ptr;
use std::io;

#[cfg(unix)]
use libc::{mmap, munmap, shm_open, shm_unlink, ftruncate, MAP_SHARED, MAP_FIXED, PROT_READ, PROT_WRITE, O_CREAT, O_RDWR, S_IRUSR, S_IWUSR};

#[cfg(windows)]
use windows_sys::Win32::System::Memory::*;
#[cfg(windows)]
use windows_sys::Win32::Foundation::{INVALID_HANDLE_VALUE, HANDLE, CloseHandle};

#[repr(align(64))]
struct CachePaddedAtomic(AtomicUsize);

pub struct MagicRingBuffer {
    ptr: *mut f32,
    capacity: usize,
    mask: usize,
    read_idx: CachePaddedAtomic,
    write_idx: CachePaddedAtomic,
    #[cfg(windows)]
    handle: HANDLE,
}

impl MagicRingBuffer {
    pub fn new(capacity: usize) -> io::Result<Self> {
        if !capacity.is_power_of_two() {
            return Err(io::Error::new(io::ErrorKind::InvalidInput, "Capacity must be power of 2"));
        }

        let bytes = capacity * std::mem::size_of::<f32>();
        
        #[cfg(unix)]
        {
            let ptr = unsafe { Self::map_unix(bytes)? };
            Ok(Self {
                ptr: ptr as *mut f32,
                capacity,
                mask: capacity - 1,
                read_idx: CachePaddedAtomic(AtomicUsize::new(0)),
                write_idx: CachePaddedAtomic(AtomicUsize::new(0)),
            })
        }

        #[cfg(windows)]
        {
            let (ptr, handle) = unsafe { Self::map_windows(bytes)? };
            Ok(Self {
                ptr: ptr as *mut f32,
                capacity,
                mask: capacity - 1,
                read_idx: CachePaddedAtomic(AtomicUsize::new(0)),
                write_idx: CachePaddedAtomic(AtomicUsize::new(0)),
                handle,
            })
        }
    }

    #[cfg(windows)]
    unsafe fn map_windows(bytes: usize) -> io::Result<(*mut u8, HANDLE)> {
        unsafe {
            // FIX: windows-sys 0.52 defines HANDLE as *mut c_void. 
            // We must cast INVALID_HANDLE_VALUE (isize) to HANDLE.
            let h_map = CreateFileMappingW(
                INVALID_HANDLE_VALUE as HANDLE, 
                ptr::null(), // Security attributes
                PAGE_READWRITE,
                0,
                bytes as u32,
                ptr::null(), // Name
            );

            // In windows-sys, a null handle is represented as 0 (null pointer)
            if h_map == 0 as HANDLE {
                return Err(io::Error::last_os_error());
            }

            // Reserve address space for 2x the buffer size
            let base_addr = VirtualAlloc(ptr::null(), 2 * bytes, MEM_RESERVE, PAGE_NOACCESS);
            if base_addr.is_null() {
                CloseHandle(h_map);
                return Err(io::Error::last_os_error());
            }

            // Release the reservation so MapViewOfFileEx can use the range
            VirtualFree(base_addr, 0, MEM_RELEASE);

            // Map the first view at the base address
            let view1 = MapViewOfFileEx(h_map, FILE_MAP_ALL_ACCESS, 0, 0, bytes, base_addr);
            if view1.Value.is_null() {
                CloseHandle(h_map);
                return Err(io::Error::last_os_error());
            }

            // Map the second view immediately following the first
            let view2 = MapViewOfFileEx(h_map, FILE_MAP_ALL_ACCESS, 0, 0, bytes, base_addr.add(bytes));
            if view2.Value.is_null() {
                UnmapViewOfFile(view1);
                CloseHandle(h_map);
                return Err(io::Error::last_os_error());
            }

            Ok((base_addr as *mut u8, h_map))
        }
    }

    #[cfg(unix)]
    unsafe fn map_unix(bytes: usize) -> io::Result<*mut u8> {
        let shm_path = format!("/mrbr_{}\0", std::process::id());
        unsafe {
            let fd = shm_open(shm_path.as_ptr() as *const i8, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR);
            if fd == -1 { return Err(io::Error::last_os_error()); }
            ftruncate(fd, bytes as i64);

            let addr = mmap(ptr::null_mut(), 2 * bytes, PROT_READ | PROT_WRITE, libc::MAP_ANONYMOUS | MAP_SHARED, -1, 0);
            if addr == libc::MAP_FAILED { return Err(io::Error::last_os_error()); }

            mmap(addr, bytes, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_FIXED, fd, 0);
            mmap(addr.add(bytes), bytes, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_FIXED, fd, 0);
            
            shm_unlink(shm_path.as_ptr() as *const i8);
            Ok(addr as *mut u8)
        }
    }

    // --- Accessor Methods ---
    pub fn write_slice(&self, len: usize) -> Option<&mut [f32]> {
        let w = self.write_idx.0.load(Ordering::Relaxed);
        let r = self.read_idx.0.load(Ordering::Acquire);
        if self.capacity - (w.wrapping_sub(r)) < len { return None; }
        unsafe { Some(std::slice::from_raw_parts_mut(self.ptr.add(w & self.mask), len)) }
    }

    pub fn commit_write(&self, len: usize) { self.write_idx.0.fetch_add(len, Ordering::Release); }

    pub fn read_slice(&self) -> &[f32] {
        let w = self.write_idx.0.load(Ordering::Acquire);
        let r = self.read_idx.0.load(Ordering::Relaxed);
        let available = w.wrapping_sub(r);
        if available == 0 { return &[]; }
        unsafe { std::slice::from_raw_parts(self.ptr.add(r & self.mask), available) }
    }

    pub fn consume(&self, len: usize) { self.read_idx.0.fetch_add(len, Ordering::Release); }
}

impl Drop for MagicRingBuffer {
    fn drop(&mut self) {
        #[cfg(windows)]
        unsafe {
            UnmapViewOfFile(MEMORY_MAPPED_VIEW_ADDRESS { Value: self.ptr as *mut _ });
            UnmapViewOfFile(MEMORY_MAPPED_VIEW_ADDRESS { Value: self.ptr.add(self.capacity) as *mut _ });
            CloseHandle(self.handle);
        }
        #[cfg(unix)]
        unsafe {
            let bytes = self.capacity * std::mem::size_of::<f32>();
            munmap(self.ptr as *mut _, 2 * bytes);
        }
    }
}

unsafe impl Send for MagicRingBuffer {}
unsafe impl Sync for MagicRingBuffer {}