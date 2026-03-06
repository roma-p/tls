const array = @import("../data_structure/array.zig");
const SequenceSplit = @import("SequenceSplit.zig");
const string = @import("../data_structure/string.zig");
const SequenceInfo = @import("SequenceInfo.zig");

const Self = @This();

array_seq_info: ArraySeqInfo,
array_seq_start_idx: ArraySeqStartIdx,
has_extra_file: bool,

const ArraySeqInfo = array.Array(100, SequenceInfo, undefined);
const ArraySeqStartIdx = array.Array(100, usize, undefined);

pub fn init() Self {
    return Self{
        .array_seq_info = ArraySeqInfo.init(),
        .array_seq_start_idx = ArraySeqStartIdx.init(),
        .has_extra_file = false,
    };
}

pub fn reset(self: *Self) void {
    self.array_seq_info.reset();
    self.array_seq_start_idx.reset();
    self.has_extra_file = false;
}

pub fn deinit(self: *Self) void {
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

