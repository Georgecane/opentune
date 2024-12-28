import sounddevice as sd
import numpy as np
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import queue
import threading
from concurrent.futures import ThreadPoolExecutor
from audiolazy import lazy_stream, Stream

class AudioDriverType(Enum):
    ASIO = "ASIO"
    WASAPI = "WASAPI" 
    DIRECTSOUND = "DirectSound"
    COREAUDIO = "CoreAudio"
    ALSA = "ALSA"
    JACK = "JACK"
    MME = "MME"
    PULSE = "PulseAudio"

@dataclass
class AudioDriverInfo:
    """Information about an audio driver"""
    index: int
    name: str
    api_name: str
    driver_type: AudioDriverType
    max_input_channels: int
    max_output_channels: int
    default_sample_rate: int
    supported_sample_rates: List[int]
    default_low_latency: float
    default_high_latency: float
    is_default: bool

@dataclass
class RecordingSettings:
    """Recording settings configuration"""
    input_device: Optional[int] = None
    sample_rate: int = 44100
    channels: int = 2
    dtype: str = 'float32'
    blocksize: int = 1024
    latency: float = 0.0
    clip_off: bool = True
    dither_off: bool = True
    never_drop_input: bool = True
    monitoring: bool = False

class AudioSettings:
    """Audio settings configuration"""
    def __init__(self):
        self.sample_rate: int = 44100
        self.buffer_size: int = 512
        self.channels: int = 2
        self.latency_mode: str = "low"
        self.input_channels: int = 2
        self.output_channels: int = 2
        self.bit_depth: int = 24
        self.use_dither: bool = True
        self.use_auto_gain: bool = False
        self.auto_gain_level: float = 0.0
        self.monitoring: bool = False

class AudioDriverError(Exception):
    """Custom exception for audio driver errors"""
    pass

class AudioRecorder:
    def __init__(self, audio_manager):
        self.audio_manager = audio_manager
        self.settings = RecordingSettings()
        self.recording = False
        self._lock = threading.Lock()
        self.recorded_chunks = []
        self._recording_stream = None
        self._record_thread = None
        self.recording_buffer = queue.Queue()
        self.peak_meters = [0.0, 0.0]  # Left and right channel peaks
        self._monitor_thread = None

    def start_recording(self) -> bool:
        """Start recording audio"""
        with self._lock:
            if self.recording:
                return False

            try:
                self.recorded_chunks = []
                self._recording_stream = sd.InputStream(
                    device=self.settings.input_device,
                    channels=self.settings.channels,
                    samplerate=self.settings.sample_rate,
                    dtype=self.settings.dtype,
                    blocksize=self.settings.blocksize,
                    latency=self.settings.latency,
                    clip_off=self.settings.clip_off,
                    dither_off=self.settings.dither_off,
                    never_drop_input=self.settings.never_drop_input,
                    callback=self._record_callback
                )
                
                self.recording = True
                self._recording_stream.start()
                
                if self.settings.monitoring:
                    self._start_monitoring()
                
                return True

            except Exception as e:
                print(f"Error starting recording: {e}")
                return False

    def stop_recording(self) -> Optional[np.ndarray]:
        """Stop recording and return recorded audio"""
        with self._lock:
            if not self.recording:
                return None

            try:
                self.recording = False
                self._recording_stream.stop()
                self._recording_stream.close()
                self._recording_stream = None
                
                if self._monitor_thread:
                    self._monitor_thread.join()
                    self._monitor_thread = None

                if self.recorded_chunks:
                    return np.concatenate(self.recorded_chunks)
                return None

            except Exception as e:
                print(f"Error stopping recording: {e}")
                return None

    def _record_callback(self, indata: np.ndarray, frames: int, time, status):
        """Callback for recording audio data"""
        if status:
            print(f"Recording status: {status}")
        
        # Update peak meters
        if indata.shape[1] >= 2:
            self.peak_meters[0] = float(np.max(np.abs(indata[:, 0])))
            self.peak_meters[1] = float(np.max(np.abs(indata[:, 1])))
        else:
            self.peak_meters[0] = self.peak_meters[1] = float(np.max(np.abs(indata)))

        # Store the recorded chunk
        self.recorded_chunks.append(indata.copy())
        
        # If monitoring is enabled, send to output buffer
        if self.settings.monitoring:
            self.recording_buffer.put(indata.copy())

    def _start_monitoring(self):
        """Start monitoring thread for real-time playback"""
        def monitor_audio():
            while self.recording:
                try:
                    data = self.recording_buffer.get(timeout=0.1)
                    self.audio_manager.audio_buffer.put(data)
                except queue.Empty:
                    continue

        self._monitor_thread = threading.Thread(target=monitor_audio, daemon=True)
        self._monitor_thread.start()

    def configure_recording(self, **kwargs) -> bool:
        """Configure recording settings"""
        with self._lock:
            try:
                for key, value in kwargs.items():
                    if hasattr(self.settings, key):
                        setattr(self.settings, key, value)
                return True
            except Exception as e:
                print(f"Error configuring recording: {e}")
                return False

    def get_recording_status(self) -> Dict:
        """Get current recording status and settings"""
        duration = (len(self.recorded_chunks) * self.settings.blocksize / 
                   self.settings.sample_rate if self.recorded_chunks else 0)
        
        return {
            'is_recording': self.recording,
            'input_device': self.settings.input_device,
            'sample_rate': self.settings.sample_rate,
            'channels': self.settings.channels,
            'monitoring': self.settings.monitoring,
            'recorded_length': duration,
            'peak_meters': self.peak_meters.copy(),
            'buffer_size': len(self.recorded_chunks)
        }

class AudioManager:
    def __init__(self):
        """Initialize Audio Manager"""
        self.drivers: Dict[int, AudioDriverInfo] = {}
        self.active_driver: Optional[AudioDriverInfo] = None
        self.settings = AudioSettings()
        self.stream = None
        self._is_initialized: bool = False
        self._lock = threading.Lock()
        self.audio_buffer = queue.Queue()
        self.recorder = AudioRecorder(self)
        
        # Initialize driver detection
        self._detect_drivers()

    def _detect_drivers(self) -> None:
        """Detect and categorize all available audio drivers"""
        try:
            host_apis = sd.query_hostapis()
            devices = sd.query_devices()
            
            for api_idx, api in enumerate(host_apis):
                api_devices = [dev for dev in devices if dev['hostapi'] == api_idx]
                
                for device in api_devices:
                    driver_info = self._create_driver_info(api, device)
                    if driver_info:
                        self.drivers[driver_info.index] = driver_info
                        
        except Exception as e:
            raise AudioDriverError(f"Failed to detect audio drivers: {e}")

    # ... [Previous AudioManager methods remain the same]

    def start_recording(self) -> bool:
        """Start recording audio"""
        return self.recorder.start_recording()

    def stop_recording(self) -> Optional[np.ndarray]:
        """Stop recording and return recorded audio"""
        return self.recorder.stop_recording()

    def configure_recording(self, **kwargs) -> bool:
        """Configure recording settings"""
        return self.recorder.configure_recording(**kwargs)

    def get_recording_status(self) -> Dict:
        """Get recording status"""
        return self.recorder.get_recording_status()

    def get_input_devices(self) -> List[AudioDriverInfo]:
        """Get list of available input devices"""
        return [driver for driver in self.drivers.values() 
                if driver.max_input_channels > 0]

    def set_monitoring(self, enabled: bool) -> bool:
        """Enable/disable input monitoring"""
        try:
            self.settings.monitoring = enabled
            self.recorder.settings.monitoring = enabled
            return True
        except Exception as e:
            print(f"Error setting monitoring: {e}")
            return False

class AmplifierMode(Enum):
    """Modes of operation for audio amplifier"""
    NORMAL = "normal"        # CPU-based processing
    ZERO_LATENCY = "zero_latency"  # Direct stream processing

class AudioAmplifier:
    def __init__(self, audio_manager):
        self.audio_manager = audio_manager
        self.mode = AmplifierMode.NORMAL
        self.gain = 1.0
        self.is_active = False
        self._lock = threading.Lock()
        self._processing_queue = queue.Queue()
        self._output_queue = queue.Queue()
        self._stream = None

        # Initialize processing thread
        self._processor_thread = threading.Thread(
            target=self._process_audio,
            daemon=True
        )
        self._processor_thread.start()

    def set_mode(self, mode: AmplifierMode) -> bool:
        with self._lock:
            try:
                was_active = self.is_active
                self.stop()
                self.mode = mode
                if was_active:
                    self.start()
                return True
            except Exception as e:
                print(f"Error changing mode: {e}")
                return False

    def start(self):
        with self._lock:
            if self.is_active:
                return
            
            self.is_active = True
            if self.mode == AmplifierMode.ZERO_LATENCY:
                self._start_zero_latency_stream()

    def stop(self):
        with self._lock:
            self.is_active = False
            if self._stream:
                self._stream.stop()
                self._stream.close()
                self._stream = None

    def set_gain(self, gain: float):
        with self._lock:
            self.gain = max(0.0, min(10.0, gain))

    def _process_audio(self):
        while True:
            try:
                if not self.is_active:
                    continue
                    
                audio_data = self.audio_manager.audio_buffer.get()
                processed_data = self._process_cpu(audio_data)
                
                if self.mode != AmplifierMode.ZERO_LATENCY:
                    self._output_queue.put(processed_data)
                
            except queue.Empty:
                continue
            except Exception as e:
                print(f"Processing error: {e}")

    def _process_cpu(self, audio_data: np.ndarray) -> np.ndarray:
        # Apply gain
        processed = audio_data * self.gain
        
        # Apply dynamic range compression
        threshold = 0.5
        ratio = 4.0
        processed = np.where(
            np.abs(processed) > threshold,
            threshold + (np.abs(processed) - threshold))