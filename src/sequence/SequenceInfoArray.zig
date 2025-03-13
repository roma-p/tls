const array = @import("../data_structure/array.zig");
const SequenceSplit = @import("SequenceSplit.zig");
const string = @import("../data_structure/string.zig");
const SequenceInfo = @import("SequenceInfo.zig");

const Self = @This();

// TODO: why "_"?
_array_seq_info: ArraySeqInfo,
_array_seq_start_idx: ArraySeqStartIdx,
has_extra_file: bool,

const ArraySeqInfo = array.Array(100, SequenceInfo, undefined);
const ArraySeqStartIdx = array.Array(100, usize, undefined);

pub fn init() Self {
    return Self{
        ._array_seq_info = ArraySeqInfo.init(),
        ._array_seq_start_idx = ArraySeqStartIdx.init(),
        .has_extra_file = false,
    };
}

pub fn reset(self: *Self) void {
    self._array_seq_info.reset();
    self._array_seq_start_idx.reset();
    self.has_extra_file = false;
}

pub fn deinit(self: *Self) void {
    self._array_seq_info.deinit();
    self._array_seq_start_idx.deinit();
    self.has_extra_file = undefined;
}

pub fn get_slice(self: *const Self) []SequenceInfo {
    return self._array_seq_info.get_slice();
}

pub fn get_longer_sequence(self: *const Self) ?SequenceInfo {
    if (self._array_seq_info.len == 0) return null;
    var ret = self._array_seq_info.array[0];
    var len = ret.sequence_split.compute_len();

    var i: usize = 1;
    while (i < self._array_seq_info.len) : (i += 1) {
        const tmp = self._array_seq_info.array[i];
        const tmp_len = tmp.sequence_split.compute_len();
        if (tmp_len > len) {
            ret = tmp;
            len = tmp_len;
        }
    }
    return ret;
}

