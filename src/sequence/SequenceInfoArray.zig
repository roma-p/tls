const array = @import("../data_structure/array.zig");
const SequenceSplit = @import("SequenceSplit.zig");
const string = @import("../data_structure/string.zig");
const SequenceInfo = @import("SequenceInfo.zig");

const Self = @This();

_array: Array,
has_extra_file: bool,

const Array = array.Array(100, SequenceInfo, undefined);

pub fn init() Self {
    return Self{
        ._array = Array.init(),
        .has_extra_file = false,
    };
}

pub fn reset(self: *Self) void {
    self._array.reset();
    self.has_extra_file = false;
}

pub fn deinit(self: *Self) void {
    self._array.deinit();
    self.has_extra_file = undefined;
}

pub fn get_slice(self: *const Self) []SequenceInfo {
    return self._array.get_slice();
}

pub fn get_longer_sequence(self: *const Self) ?SequenceInfo {
    if (self._array.len == 0) return null;
    var ret = self._array.array[0];
    var len = ret.sequence_split.compute_len();

    var i: usize = 1;
    while (i < self._array.len) : (i += 1) {
        const tmp = self._array.array[i];
        const tmp_len = tmp.sequence_split.compute_len();
        if (tmp_len > len) {
            ret = tmp;
            len = tmp_len;
        }
    }
    return ret;
}

