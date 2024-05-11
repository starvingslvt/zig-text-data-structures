const std = @import("std");
const assert = std.debug.assert;

pub fn GapBufferType() type {
    return struct {
        const GapBuffer = @This();

        const GapBufferError = error{
            GrowSizeLessThanOne,
            FailedToGrow,
        };

        allocator: std.mem.Allocator,
        grow_size: usize,
        size: usize,
        gap_start: usize,
        gap_end: usize,
        buffer: []u8,

        pub fn init(initial_size: usize, grow_size: usize, allocator: std.mem.Allocator) !GapBuffer {
            if (grow_size == 0) return GapBufferError.GrowSizeLessThanOne;

            var true_initial_size: usize = undefined;
            if (initial_size == 0) {
                true_initial_size = grow_size;
            } else {
                true_initial_size = initial_size;
            }

            return GapBuffer{
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

        pub fn insertChar(buffer: *GapBuffer, char: u8) !void {
            if (buffer.gap_start == buffer.gap_end) {
                buffer._grow() catch return GapBufferError.FailedToGrow;
            }

            buffer.buffer[buffer.gap_start] = char;
            buffer.gap_start += 1;
        }

        pub fn insertStr(buffer: *GapBuffer, str: []const u8) !void {
            for (str) |char| {
                try buffer.insertChar(char);
            }
        }

        pub fn shiftBufferToPosition(buffer: *GapBuffer, position: usize) !void {
            assert(buffer.gap_end >= buffer.gap_start);

            const gap_length = buffer.gap_end - buffer.gap_start;
            const clamped_position = @min(position, buffer.size - gap_length);

            var char_delta: usize = 0;
            if (clamped_position < buffer.gap_start) {
                char_delta = buffer.gap_start - clamped_position;
                try buffer._memmove(buffer.buffer[buffer.gap_end - char_delta .. buffer.gap_end], buffer.buffer[buffer.gap_start - char_delta .. buffer.gap_start], char_delta);
                buffer.gap_start -= char_delta;
                buffer.gap_end -= char_delta;
            } else if (clamped_position > buffer.gap_start) {
                char_delta = clamped_position - buffer.gap_start;
                try buffer._memmove(buffer.buffer[buffer.gap_start .. buffer.gap_start + char_delta], buffer.buffer[buffer.gap_end .. buffer.gap_end + char_delta], char_delta);
                buffer.gap_start += char_delta;
                buffer.gap_end += char_delta;
            }
        }

        fn _grow(buffer: *GapBuffer) !void {
            const new_size = buffer.size + buffer.grow_size;

            const resize_result = buffer.allocator.resize(buffer.buffer, new_size);
            if (resize_result == false) {
                const new_buffer = try buffer.allocator.alloc(u8, new_size);
                @memcpy(new_buffer[0..buffer.size], buffer.buffer[0..buffer.size]);

                buffer.allocator.free(buffer.buffer);
                buffer.buffer = new_buffer;
            }

            buffer.size = new_size;
            buffer.gap_end += buffer.grow_size;
        }

        fn _memmove(buffer: *GapBuffer, dest: []const u8, src: []const u8, size: usize) !void {
            const temp_buffer = try buffer.allocator.alloc(u8, size);
            defer buffer.allocator.free(temp_buffer);

            @memcpy(temp_buffer, src);
            @memcpy(dest, temp_buffer);
        }
    };
}
