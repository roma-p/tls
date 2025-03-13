const std = @import("std");
const SequenceInfo = @import("SequenceInfo.zig");
const SequenceInfoArray = @import("SequenceInfoArray.zig");
const sequence_utils = @import("sequence_utils.zig");
const DirEntry = @import("../file_structure/DirContent.zig").DirEntry;

const Self = @This();

sequence_info_array: *SequenceInfoArray,

_dir_entry_slice: []const DirEntry,
_dir_entry_buff_1: DirEntry,  // TODO: make this pointer.
_dir_entry_buff_2: DirEntry,  // TODO: make this pointer.
_dir_entry_curr: DirEntry,
_i: usize, // use for dir_entry_slice
_j: usize, // use for sequence_info_array.array
_parsing_seq_state: ParsingSeqState,

const ParsingSeqState = enum {
    LookingForSequence,
    ParsingSequence,
};

pub fn init() Self {
    return Self{
        .sequence_info_array = undefined,
        ._dir_entry_slice = undefined,
        ._dir_entry_buff_1 = undefined,
        ._dir_entry_buff_2 = undefined,
        ._dir_entry_curr = undefined,
        ._i = undefined,
        ._j = undefined,
        ._parsing_seq_state = undefined,
    };
}

pub fn deinit(self: *Self) void {
    self.reset();
}

pub fn reset(self: *Self) void {
    self.sequence_info_array = undefined;
    self._dir_entry_slice = undefined;
    self._dir_entry_buff_1 = undefined;
    self._dir_entry_buff_2 = undefined;
    self._dir_entry_curr = undefined;
    self._i = undefined;
    self._j = undefined;
    self._parsing_seq_state = undefined;
}

//TODO NEXT REDO WITH I / J -> copy paste algo until it rework... we clean / redo later.

pub fn parse_sequence(
        self: *Self,
        dir_entry_slice: []const DirEntry,
        sequence_info_array: *SequenceInfoArray,

) void {
    self.reset();
    self.sequence_info_array = sequence_info_array;
    self.sequence_info_array.reset();

    self._i = 1;
    self._j = 0;

    if (dir_entry_slice.len == 0) return;  // FIXME: actually: 2! otherwise, buffer_2 can stay undefined...

    self._dir_entry_slice = dir_entry_slice;
    self._dir_entry_buff_1 = dir_entry_slice[0];
    self._dir_entry_buff_2 = undefined;
    // self._dir_entry_buff_2 = dir_entry_slice[1];
    self._parsing_seq_state = ParsingSeqState.LookingForSequence;

    // while (self._i < self._dir_entry_slice.len- 1) {
    while (self._i < self._dir_entry_slice.len) {
        self._dir_entry_curr = self._dir_entry_slice[self._i];
        self._i += 1;
        switch (self._parsing_seq_state) {
            .LookingForSequence => self._state_looking_for_sequence(),
            .ParsingSequence => self._state_parsing_sequence(),
        }
    }

    if (self._parsing_seq_state == ParsingSeqState.ParsingSequence) self._j += 1;
    self.sequence_info_array._array_seq_info.len = self._j;

    for (self.sequence_info_array._array_seq_info.get_slice(), 0..) |seq_info, k| {
        self.sequence_info_array._array_seq_start_idx.array[k] = seq_info.idx_start;
    }
    std.mem.sort(
        usize,
        &self.sequence_info_array._array_seq_start_idx.array,
        {},
        comptime std.sort.asc(usize)
    );
    self.sequence_info_array._array_seq_start_idx.len = self._j;
}

fn _state_looking_for_sequence(self: *Self) void {
    switch (self._dir_entry_curr.kind) {
        .file => {
            self._dir_entry_buff_2 = self._dir_entry_curr;
            const tmp = _build_seq_info_if_seq(
                self._dir_entry_buff_1.name.get_slice(),
                self._dir_entry_buff_2.name.get_slice(),
                self._i - 1,
            );
            if (tmp != null) {
                self.sequence_info_array._array_seq_info.array[self._j] = tmp.?;
                self._parsing_seq_state = ParsingSeqState.ParsingSequence;
            } else {
                self._dir_entry_buff_1 = self._dir_entry_buff_2;
                self.sequence_info_array.has_extra_file = true;
            }
        },
        else => {
            self.sequence_info_array.has_extra_file = true;
        },
    }
}

fn _state_parsing_sequence(self: *Self) void {
    var finish_parsing_sequence = false;
    var last = &self.sequence_info_array._array_seq_info.array[self._j];
    switch (self._dir_entry_curr.kind) {
        .file => {
            const seq_nb = sequence_utils.check_file_belong_to_sequence(
                self._dir_entry_curr.name.get_slice(),
                last.pattern_before.get_slice(),
                last.pattern_after.get_slice(),
            );
            if (seq_nb == null) {
                finish_parsing_sequence = true;
            } else {
                last.sequence_split.add_value(seq_nb.?);
            }
        },
        else => {
            finish_parsing_sequence = true;
        },
    }
    if (finish_parsing_sequence) {
        self._parsing_seq_state = ParsingSeqState.LookingForSequence;
        self._j += 1;
    }
}
fn _build_seq_info_if_seq(
    filename_1: []const u8,
    filename_2: []const u8,
    i_start: usize,
) ?SequenceInfo {
    const sequence_result_or_null = sequence_utils.check_is_sequence_using_two_filenames(
        filename_1,
        filename_2,
    );

    if (sequence_result_or_null == null) return null;

    const sequence_result = sequence_result_or_null.?;
    const pattern_before = filename_1[0..sequence_result.number_start_idx];
    const pattern_after = filename_2[sequence_result.number_end_idx_filename_1..];

    var ret = SequenceInfo.init();
    ret.pattern_before.append_string(pattern_before);
    ret.pattern_after.append_string(pattern_after);
    ret.sequence_split.add_value(sequence_result.seq_number_filenam_1);
    ret.sequence_split.add_value(sequence_result.seq_number_filenam_2);
    ret.idx_start = i_start;
    return ret;
}
