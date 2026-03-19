const std = @import("std");
const DynamicArray = @import("../data_structure/darray.zig").DynamicArray;
const SequenceSplit = @import("SequenceSplit.zig");
const string = @import("../data_structure/string.zig");
const SequenceInfo = @import("SequenceInfo.zig");

const Self = @This();

const SEQ_INIT_SIZE = 8;

array_seq_info: ArraySeqInfo,
array_seq_start_idx: ArraySeqStartIdx,
has_extra_file: bool,

const ArraySeqInfo = DynamicArray(SEQ_INIT_SIZE, SequenceInfo, undefined);
const ArraySeqStartIdx = DynamicArray(SEQ_INIT_SIZE, usize, undefined);

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .array_seq_info = try ArraySeqInfo.init(allocator),
        .array_seq_start_idx = try ArraySeqStartIdx.init(allocator),
        .has_extra_file = false,
    };
}

pub fn reset(self: *Self) void {
    self.array_seq_info.reset();
    self.array_seq_start_idx.reset();
    self.has_extra_file = false;
}

pub fn deinit(self: *Self) void {
    self.array_seq_info.deinit();
    self.array_seq_start_idx.deinit();
    self.* = undefined;
}

pub fn get_slice(self: *const Self) []const SequenceInfo {
    return self.array_seq_info.get_slice();
}

pub fn get_longer_sequence(self: *const Self) ?SequenceInfo {
    if (self.array_seq_info.len == 0) return null;
    var ret = self.array_seq_info.array[0];
    var len = ret.sequence_split.compute_len();

    var i: usize = 1;
    while (i < self.array_seq_info.len) : (i += 1) {
        const tmp = self.array_seq_info.array[i];
        const tmp_len = tmp.sequence_split.compute_len();
        if (tmp_len > len) {
            ret = tmp;
            len = tmp_len;
        }
    }
    return ret;
}
