const std = @import("std");
const constants = @import("constants.zig");

pub const SequenceSplit = struct {
    /// holds compress data of a sequence of numbers on SequenceSplit.array
    /// eg: (1 0 3 2 7 2) shall be understood as (1-0 3-2, 7-2)
    /// which translate as an uncompressed sequence to (1 3 4 5 7 8 9)
    array: [constants.MAX_LEN_FOR_SEQUENCE_SPLIT]u16, // TODO: this bigger and comptime?
    split_end: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .array = [_]u16{0} ** constants.MAX_LEN_FOR_SEQUENCE_SPLIT, // we use max: 1ko
            .split_end = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        std.mem.set(u16, &self.array, 0);
        self.split_end = 0;
        self.array = undefined;
    }

    pub fn reset(self: *Self) void {
        self.split_end = 0;
    }

    pub fn add_value(self: *Self, value: u16) void {
        if (self.split_end == 0) {
            self.array[0] = value;
            self.array[1] = 0;
            self.split_end = 1;
            return;
        }

        var i: usize = 0;
        var j: usize = 0;
        while (i < self.split_end) : (i += 1) {
            j = i * 2;
            if (value < self.array[j]) {
                if (value + 1 == self.array[j]) {
                    self.array[j] = value;
                    self.array[j + 1] += 1;
                    return;
                } else {
                    self._shift_right_from_idx(j, 2);
                    self.array[j] = value;
                    self.array[j + 1] = 0;
                    self.split_end += 1;
                    return;
                }
            } else if (value == self.array[j]) {
                return;
            } else if (value == self.array[j] + self.array[j + 1] + 1) {
                self.array[j + 1] += 1;
                if (value + 1 == self.array[j + 2]) {
                    self.array[j + 1] += 1 + self.array[j + 3];
                    self._shift_left_from_idx(j + 4, 2);
                    self.split_end -= 1;
                }
                return;
            }
        }
        if (j == self.array.len) return; // TODO return err here!!!
        //
        j += 2;
        self.array[j] = value;
        self.array[j + 1] = 0;
        self.split_end += 1;
    }

    pub fn print_debug(self: *Self) void {
        var i: usize = 0;
        while (i < self.split_end) : (i += 1) {
            std.debug.print("{}-{} ", .{ self.array[i * 2], self.array[i * 2 + 1] });
        }
        std.debug.print("\n", .{});
    }

    pub fn compute_len(self: *Self) usize {
        var i: usize = 0;
        var j: usize = 0;
        while (i < self.split_end) : (i += 1) {
            j += 1 + self.array[i + 1];
        }
        return j;
    }

    fn _shift_right_from_idx(self: *Self, start_idx: usize, shift_increment: usize) void {
        if (start_idx > self.array.len - 1) return; // TODO ERR?
        var i: usize = self.split_end * 2;
        while (i >= start_idx) : (i -= 1) {
            if ((i + shift_increment) > self.array.len - 1) continue;

            self.array[i + shift_increment] = self.array[i];
            if (i == 0) break;
        }
    }

    fn _shift_left_from_idx(self: *Self, start_idx: usize, shift_increment: usize) void {
        if (start_idx > self.array.len - 1) return; // TODO ERR
        if (shift_increment > self.array.len - start_idx) return; // TODO RETURN ERR?;
        var i: usize = start_idx;
        while (i < self.split_end * 2) : (i += 1) {
            if (i < shift_increment) continue;
            self.array[i - shift_increment] = self.array[i];
        }
    }
};

///////////////////////////////////////////////////////////////////////////////

test "test_sequence_split_shift_left" {
    var sequence_split = SequenceSplit.init();
    sequence_split.split_end = 5;
    sequence_split.array = [_]u16{ 1, 2, 3, 4, 0, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 6);

    // valid
    sequence_split._shift_left_from_idx(3, 2);
    try std.testing.expectEqual([_]u16{ 1, 4, 0, 0, 0 }, sequence_split.array[0..5].*);

    // overflow
    sequence_split.array = [_]u16{ 1, 2, 3, 4, 0, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 6);
    sequence_split._shift_left_from_idx(1, 2);
    try std.testing.expectEqual([_]u16{ 3, 4, 0, 0, 0 }, sequence_split.array[0..5].*);

    // error case (silenced for now)
    sequence_split.array = [_]u16{ 1, 2, 3, 4, 0, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 6);
    sequence_split._shift_left_from_idx(20, 1);

    sequence_split.array = [_]u16{ 1, 2, 3, 4, 0, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 6);
    sequence_split._shift_left_from_idx(3, 100);
}

test "test_sequence_split_right" {
    var sequence_split = SequenceSplit.init();
    sequence_split.array = [_]u16{ 1, 2, 3, 4, 0, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 6);
    sequence_split.split_end = 5;
    sequence_split._shift_right_from_idx(1, 2);
    try std.testing.expectEqual([_]u16{ 1, 2, 3, 2, 3, 4 }, sequence_split.array[0..6].*);
    sequence_split.array = [_]u16{ 1, 2, 3, 4, 0, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 6);
    sequence_split._shift_right_from_idx(1, 100);
    try std.testing.expectEqual([_]u16{ 1, 2, 3, 4, 0 }, sequence_split.array[0..5].*);
}

test "test_sequence_split_add_value" {
    var sequence_split = SequenceSplit.init();
    sequence_split.add_value(2);
    try std.testing.expectEqual([_]u16{ 2, 0 }, sequence_split.array[0..2].*);
    try std.testing.expectEqual(1, sequence_split.split_end);
    sequence_split.add_value(5);
    try std.testing.expectEqual([_]u16{ 2, 0, 5, 0 }, sequence_split.array[0..4].*);
    try std.testing.expectEqual(2, sequence_split.split_end);
    sequence_split.add_value(1);
    try std.testing.expectEqual([_]u16{ 1, 1, 5, 0 }, sequence_split.array[0..4].*);
    try std.testing.expectEqual(2, sequence_split.split_end);
    sequence_split.add_value(4);
    try std.testing.expectEqual([_]u16{ 1, 1, 4, 1 }, sequence_split.array[0..4].*);
    try std.testing.expectEqual(2, sequence_split.split_end);
    sequence_split.add_value(10);
    try std.testing.expectEqual([_]u16{ 1, 1, 4, 1, 10, 0 }, sequence_split.array[0..6].*);
    try std.testing.expectEqual(3, sequence_split.split_end);
    sequence_split.add_value(7);
    try std.testing.expectEqual([_]u16{ 1, 1, 4, 1, 7, 0, 10, 0 }, sequence_split.array[0..8].*);
    try std.testing.expectEqual(4, sequence_split.split_end);
    sequence_split.add_value(9);
    try std.testing.expectEqual([_]u16{ 1, 1, 4, 1, 7, 0, 9, 1 }, sequence_split.array[0..8].*);
    try std.testing.expectEqual(4, sequence_split.split_end);
    sequence_split.add_value(8);
    try std.testing.expectEqual([_]u16{ 1, 1, 4, 1, 7, 3 }, sequence_split.array[0..6].*);
    try std.testing.expectEqual(3, sequence_split.split_end);
    sequence_split.add_value(6);
    try std.testing.expectEqual([_]u16{ 1, 1, 4, 6 }, sequence_split.array[0..4].*);
    try std.testing.expectEqual(2, sequence_split.split_end);
    sequence_split.add_value(3);
    try std.testing.expectEqual([_]u16{ 1, 9 }, sequence_split.array[0..2].*);
    try std.testing.expectEqual(1, sequence_split.split_end);
}
