// dspengine.rs

/* DSP Engine Implementation */

#![allow(warnings)]

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use once_cell::sync::Lazy;
use std::sync::{Arc, Mutex};

use crate::dspapi::*;
use crate::pmanager::PMANAGER;
use crate::mrbr::MagicRingBuffer as Buffer;

pub const DSPENGINE_VERSION: &str = "0.1.0";

/// The Universal Audio Trait. 
/// All internal nodes and external plugin wrappers (VST3, CLAP, LV2) must implement this.
pub trait AudioNode: Send {
    fn process(&mut self, buffer: &mut [f32]);
    fn set_param(&mut self, param_id: u32, payload: &[u8]);
    fn get_id(&self) -> u32;
    fn get_name(&self) -> &str;
}

/// Thread-safety wrapper to allow the CPAL Stream to be sent between threads.
struct SendStream(cpal::Stream);
unsafe impl Send for SendStream {}

/// Global handle to the active audio stream.
static ACTIVE_STREAM: Mutex<Option<SendStream>> = Mutex::new(None);

/// Global Singleton for the DSP Engine.
pub static DSPENGINE: Lazy<Mutex<DspEngine>> = Lazy::new(|| {
    Mutex::new(DspEngine::new(1, "OpenTune Universal Host", 44100, 1024))
});

pub struct DspEngine {
    pub engine_id: u32,
    pub description: &'static str,
    pub is_running: bool,
    pub sample_rate: u32,
    pub buffer_size: usize,
    pub buffer: Arc<Buffer>,
    pub command_queue: Arc<Mutex<Vec<Command>>>,
    /// The Rack: A dynamic list of loaded plugins and DSP nodes.
    pub nodes: Arc<Mutex<Vec<Box<dyn AudioNode>>>>, 
}

impl DspEngine {
    pub fn new(engine_id: u32, description: &'static str, sample_rate: u32, buffer_size: usize) -> Self {
        let buffer = Arc::new(Buffer::new(buffer_size).expect("MagicRingBuffer Initialization Failed"));
        DspEngine {
            engine_id,
            description,
            is_running: false,
            sample_rate,
            buffer_size,
            buffer,
            command_queue: Arc::new(Mutex::new(Vec::new())),
            nodes: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Initializes and starts the high-priority audio thread.
    pub fn start(&mut self) -> Result<(), String> {
        if self.is_running { return Ok(()); }

        let host = cpal::default_host();
        let device = host.default_output_device().ok_or("No output device found")?;
        
        let config = cpal::StreamConfig {
            channels: 2,
            sample_rate: cpal::SampleRate(self.sample_rate),
            buffer_size: cpal::BufferSize::Fixed(self.buffer_size as u32),
        };

        // Clone Arcs for use inside the audio thread closure
        let ring_buffer = Arc::clone(&self.buffer);
        let in_queue = Arc::clone(&self.command_queue);
        let active_nodes = Arc::clone(&self.nodes);

        let stream = device.build_output_stream(
            &config,
            move |output: &mut [f32], _: &cpal::OutputCallbackInfo| {
                
                // --- 1. DYNAMIC COMMAND PROCESSING ---
                // We use try_lock to avoid blocking the audio thread.
                if let Ok(mut commands) = in_queue.try_lock() {
                    for cmd in commands.drain(..) {
                        match cmd.command_id {
                            0 => { // Command: Add Plugin/Node
                                if let Ok(mut pm) = PMANAGER.lock() {
                                    if let Some(node) = pm.create_node(&cmd.description) {
                                        if let Ok(mut nodes) = active_nodes.lock() {
                                            nodes.push(node);
                                        }
                                    }
                                }
                            }
                            2 => { // Command: Set Node Parameter
                                if let Ok(mut nodes) = active_nodes.lock() {
                                    if let Some(node) = nodes.iter_mut().find(|n| n.get_id() == cmd.node_id) {
                                        node.set_param(cmd.param_id, &cmd.payload);
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                }

                // --- 2. FETCH RAW AUDIO FROM RING BUFFER ---
                let available = ring_buffer.read_slice();
                let len = output.len().min(available.len());
                
                // Copy samples from the input buffer to the hardware output
                output[..len].copy_from_slice(&available[..len]);
                
                // Zero out the rest of the buffer if we have a shortage of data (underflow)
                if len < output.len() {
                    output[len..].fill(0.0);
                }
                
                ring_buffer.consume(len);

                // --- 3. SEQUENTIAL DSP PROCESSING (THE RACK) ---
                // We process the audio through every node in the vector sequentially.
                // Note: try_lock is critical here to ensure zero-latency.
                if let Ok(mut nodes) = active_nodes.try_lock() {
                    for node in nodes.iter_mut() {
                        node.process(output);
                    }
                }
            },
            |err| eprintln!("Critical Audio Stream Error: {}", err),
            None
        ).map_err(|e| e.to_string())?;

        // Start playback
        stream.play().map_err(|e| e.to_string())?;
        
        // Store the stream globally so it doesn't get dropped
        if let Ok(mut gs) = ACTIVE_STREAM.lock() {
            *gs = Some(SendStream(stream));
        }
        
        self.is_running = true;
        println!("[DspEngine] Audio Thread Started successfully.");
        Ok(())
    }

    /// Stops the audio thread and clears the active stream.
    pub fn stop(&mut self) {
        if let Ok(mut gs) = ACTIVE_STREAM.lock() {
            *gs = None;
        }
        self.is_running = false;
        println!("[DspEngine] Audio Thread Stopped.");
    }

    /// Helper to push samples into the engine for playback
    pub fn push_samples(&self, samples: &[f32]) -> usize {
        if let Some(write_slice) = self.buffer.write_slice(samples.len()) {
            write_slice.copy_from_slice(samples);
            self.buffer.commit_write(samples.len());
            samples.len()
        } else {
            0
        }
    }
}