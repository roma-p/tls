const std = @import("std");
const SequenceSplit = @import("SequenceSplit.zig");
const string = @import("../data_structure/string.zig");

const Self = @This();

sequence_split: SequenceSplit,
pattern_after: string.StringLongUnicode,
pattern_before: string.StringLongUnicode,
idx_start: usize,

// TODO: no reset?
pub fn init() Self {
    return Self{
        .sequence_split = SequenceSplit.init(),
        .pattern_after = string.StringLongUnicode.init(),
        .pattern_before = string.StringLongUnicode.init(),
        .idx_start = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.sequence_split.deinit();
    self.pattern_before.deinit();
    self.pattern_after.deinit();

    self.sequence_split = undefined;
    self.pattern_before = undefined;
    self.pattern_after = undefined;
    self.idx_start = undefined;
}

pub fn print_debug(self: *const Self) void {
    std.debug.print("sequence info : {s}[]{s}  / start at: {d} / ", .{
        self.pattern_before.get_slice(),
        self.pattern_after.get_slice(),
        self.idx_start,
    });
    self.sequence_split.print_debug();
}
