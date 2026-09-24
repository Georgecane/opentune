const std = @import("std");

pub const Result = error{
    InvalidArgument,
    InvalidState,
    Unsupported,
    NotFound,
    AlreadyExists,
    OutOfMemory,
    DeviceUnavailable,
    BackendUnavailable,
    IoFailure,
};

pub const Sample = f32;
pub const SampleRate = u32;
pub const FrameCount = u32;
pub const ChannelCount = u32;
pub const TransportSample = u64;

pub const AudioFormat = struct {
    sample_rate: SampleRate,
    channels: ChannelCount,

    pub fn init(sample_rate: SampleRate, channels: ChannelCount) AudioFormat {
        return .{
            .sample_rate = sample_rate,
            .channels = channels,
        };
    }
};

pub const ProcessContext = struct {
    sample_rate: SampleRate,
    block_size: FrameCount,
    transport_sample: TransportSample,
};

pub const DeviceId = struct {
    value: u64,
};

pub const DeviceInfo = struct {
    id: DeviceId,
    name: []const u8,
    is_input: bool,
    is_output: bool,
    min_channels: ChannelCount,
    max_channels: ChannelCount,
};

pub const DeviceDirection = enum {
    input,
    output,
    duplex,
};
