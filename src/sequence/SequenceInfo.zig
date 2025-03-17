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

pub fn print_debug(self: *const Self) void {
    std.debug.print(
        "sequence info : {s}[]{s}  / start at: {d} / ",
        .{
            self.pattern_before.get_slice(),
            self.pattern_after.get_slice(),
            self.idx_start,
        }
    );
    self.sequence_split.print_debug();
}

