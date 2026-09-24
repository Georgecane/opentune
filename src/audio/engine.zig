const audio = @import("audio.zig");

pub const ProcessingContext = struct {
    sample_rate: u32,
    block_size: u32,
    transport_sample: u64,
};

pub const AudioEngine = struct {
    context: ProcessingContext,

    pub fn init(sample_rate: u32, block_size: u32) AudioEngine {
        return .{
            .context = .{
                .sample_rate = sample_rate,
                .block_size = block_size,
                .transport_sample = 0,
            },
        };
    }

    pub fn process(self: *AudioEngine, buffer: *audio.AudioBuffer, oscillator: *audio.Oscillator) void {
        oscillator.sample_rate = @floatFromInt(self.context.sample_rate);
        oscillator.process(buffer, 0.08);
        self.context.transport_sample += buffer.frames;
    }
};

test "engine advances transport" {
    var samples = [_]audio.Sample{0} ** 8;
    var buffer = audio.AudioBuffer.init(&samples, 2, 48_000);
    var engine = AudioEngine.init(48_000, 4);
    var oscillator = audio.Oscillator{};
    engine.process(&buffer, &oscillator);
    try @import("std").testing.expectEqual(@as(u64, 4), engine.context.transport_sample);
}
