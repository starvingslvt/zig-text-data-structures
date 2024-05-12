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

        pub fn getAsSlice(buffer: *GapBuffer) ![]const u8 {
            const left = buffer.buffer[0..buffer.gap_start];
            const right = buffer.buffer[buffer.gap_end..buffer.size];
            const slice = try buffer.allocator.alloc(u8, left.len + right.len);

            @memcpy(slice[0..left.len], left);
            @memcpy(slice[left.len..slice.len], right);

            return slice;
        }

        fn _grow(buffer: *GapBuffer) !void {
            const new_size = buffer.size + buffer.grow_size;
            const start = buffer.gap_start;
            const end = buffer.gap_end;

            buffer.buffer = try buffer.allocator.realloc(buffer.buffer, new_size);
            buffer.gap_start = new_size - buffer.grow_size;
            buffer.gap_end = buffer.size;

            buffer.shiftBufferToPosition(start) catch |e| {
                buffer.gap_start = start;
                buffer.gap_end = end;
                return e;
            };

            buffer.size = new_size;
        }

        fn _memmove(buffer: *GapBuffer, dest: []u8, src: []const u8, size: usize) !void {
            const temp_buffer = try buffer.allocator.alloc(u8, size);
            defer buffer.allocator.free(temp_buffer);

            @memcpy(temp_buffer, src);
            @memcpy(dest, temp_buffer);
        }
    };
}

test "GapBuffer" {
    const testing = std.testing;
    const expect = testing.expect;

    var gap_buffer = try GapBufferType().init(2, 2, testing.allocator);
    defer gap_buffer.deinit();

    try gap_buffer.insertChar('h');
    try gap_buffer.insertChar('e');
    try gap_buffer.insertChar('l');
    try gap_buffer.insertChar('l');
    try gap_buffer.insertChar('o');
    try gap_buffer.insertChar(' ');
    try gap_buffer.insertStr("zig!");

    try gap_buffer.shiftBufferToPosition(5);
    try gap_buffer.insertStr("w,");

    const bufSlice = try gap_buffer.getAsSlice();
    defer gap_buffer.allocator.free(bufSlice);

    const buffer_check = [_]u8{ 'h', 'e', 'l', 'l', 'o', 'w', ',', ' ', 'z', 'i', 'g', '!' };

    try expect(std.mem.eql(u8, bufSlice, &buffer_check));
}
