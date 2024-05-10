const std = @import("std");

pub fn GapBufferType() type {
    return struct {
        const GapBuffer = @This();

        const GapBufferError = error {
            GrowSizeLessThanOne,
        };

        allocator: std.mem.Allocator,
        grow_size: usize,
        size: usize,
        gap_start: usize,
        gap_end: usize,
        buffer: []u8,

        pub fn init(initial_size: usize, grow_size: usize, allocator: std.mem.Allocator) !GapBuffer {
            if (grow_size == 0) return GapBufferError.GrowSizeLessThanOne;

            const true_initial_size = if (initial_size == 0) {
                grow_size;
            } else {
                initial_size;
            };

            return GapBuffer {
                .allocator = allocator,
                .grow_size = grow_size,
                .size = initial_size,
                .gap_start = 0,
                .gap_end = true_initial_size,
                .buffer = try allocator.alloc(u8, true_initial_size),
            };
        }

        pub fn deinit(buffer: *GapBuffer) void {
            buffer.allocator.free(buffer.buffer);
        }

        pub fn insertChar(buffer: *GapBuffer, char: u8) void {}
        pub fn insertStr(buffer: *GapBuffer, str: []const u8) void {}
        pub fn shiftBufferToPosition(buffer: *GapBuffer, position: usize) void {}

        fn _grow(buffer: *GapBuffer) void {
            const new_size = buffer.size + buffer.grow_size;
            
            buffer.allocator.resize(buffer.buffer, new_size) catch {
                const new_buffer = try buffer.allocator.alloc(u8, new_size);
                @memcpy(new_buffer[0..buffer.size], buffer.buffer[0..buffer.size]);

                buffer.allocator.free(buffer.buffer);
                buffer.buffer = new_buffer;
            };

            buffer.size = new_size;
            buffer.gap_end += buffer.grow_size;
        }
    };
}
