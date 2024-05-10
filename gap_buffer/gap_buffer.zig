const std = @import("std");

pub fn GapBufferType() type {
    return struct {
        const GapBuffer = @This();

        const GapBufferError = error {
            GrowSizeLessThanOne,
        };

        allocator: std.mem.Allocator,
        size: usize,
        gap_start: usize,
        gap_end: usize,
        buffer: []u8,

        pub fn init(allocator: std.mem.Allocator) GapBuffer {}
        pub fn deinit(buffer: *GapBuffer) void {}
        pub fn insertChar(buffer: *GapBuffer, char: u8) void {}
        pub fn insertStr(buffer: *GapBuffer, str: []const u8) void {}
        pub fn shiftBufferToPosition(buffer: *GapBuffer, position: usize) void {}
        fn _grow(buffer: *GapBuffer) void {}
    };
}
