const std = @import("std");
const fs = std.fs;

const sequence_split_mod = @import("sequence_split.zig");
const sequence_utils = @import("sequence_utils.zig");
const string = @import("string.zig");
const constants = @import("constants.zig");
const dir_content = @import("dir_content.zig");
const DirContent = dir_content.DirContent;

_dir_content: DirContent,
_sequence_info_buff: [100]SequenceInfo,
_sequence_info_buff_len: usize,

// missing here: multiple sequences. flag to capture or not rights.

const SequenceInfo = struct {
    sequence_split: sequence_split_mod.SequenceSplit,
    pattern_after: string.StringLongUnicode,
    pattern_before: string.StringLongUnicode,

    pub fn init() SequenceInfo {
        return SequenceInfo{
            .sequence_split = sequence_split_mod.SequenceSplit.init(),
            .pattern_after = string.StringLongUnicode.init(),
            .pattern_before = string.StringLongUnicode.init(),
        };
    }
};

const ParsingSeqState = enum {
    LookingForSequence,
    ParsingSequence,
};

const Self = @This();

pub fn init() Self {
    return Self{
        ._dir_content = DirContent.init(),
        ._sequence_info_buff = [_]SequenceInfo{undefined} ** 100,
        ._sequence_info_buff_len = 0,
    };
}

pub fn reset(self: *Self) void {
    self._dir_content.reset();
    self._sequence_info_buff = [_]SequenceInfo{undefined} ** 100;
    self._sequence_info_buff_len = 0;
}

pub fn deinit(self: *Self) void {
    self._dir_content.deinit();
    self._dir_content = undefined;
    self._sequence_info_buff = undefined;
    self._sequence_info_buff_len = undefined;
}

// TODO: 1. split into proper state machine.
// TODO: 2. add posix support.
// TODO: 3. add  idx of the first file of the dir (i) -> to know where to put it in the term.
pub fn populate(self: *Self, dir: *const fs.Dir) !void {
    self._dir_content.reset();
    try self._dir_content.populate(dir);
    const dir_content_slice = self._dir_content.get_slice();

    if (dir_content_slice.len == 0) return;

    var entry_buffer_1: DirContent.DirEntry = dir_content_slice[0];
    var entry_buffer_2: DirContent.DirEntry = undefined;

    var has_extra_file = false; // TODO: use me

    var i: usize = 1; // idx on dir_content_slice
    var j: usize = 0; // idx on sequence buff info.

    var state = ParsingSeqState.LookingForSequence;

    // find the first filename used to compare to the others...
    while (i < dir_content_slice.len) {
        const e = dir_content_slice[i];
        i += 1;

        if (state == ParsingSeqState.LookingForSequence) {
            switch (e.kind) {
                // AS STATE...
                .file => {
                    entry_buffer_2 = e;
                    const tmp = _build_seq_info_if_seq(
                        entry_buffer_1.name.get_slice(),
                        entry_buffer_2.name.get_slice(),
                    );
                    if (tmp != null) {
                        self._sequence_info_buff[j] = tmp.?;
                        state = ParsingSeqState.ParsingSequence;
                    } else {
                        entry_buffer_1 = entry_buffer_2;
                        has_extra_file = true;
                    }
                },
                else => {},
            }
        } else {
            var finish_parsing_sequence = false;
            switch (e.kind) {
                .file => {
                    const seq_nb = sequence_utils.check_file_belong_to_sequence(
                        e.name.get_slice(),
                        self._sequence_info_buff[j].pattern_before.get_slice(),
                        self._sequence_info_buff[j].pattern_after.get_slice(),
                    );
                    if (seq_nb == null) {
                        finish_parsing_sequence = true;
                    } else {
                        self._sequence_info_buff[j].sequence_split.add_value(seq_nb.?);
                    }
                },
                else => {
                    finish_parsing_sequence = true;
                },
            }

            if (finish_parsing_sequence) {
                state = ParsingSeqState.LookingForSequence;
                j += 1;
            }
        }
    }
    if (state == ParsingSeqState.ParsingSequence) j += 1;
    self._sequence_info_buff_len = j;
}

pub fn get_slice(self: *const Self) []SequenceInfo {
    return self._sequence_info_buff[0..self._sequence_info_buff_len];
}

pub fn get_longer_sequence(self: *const Self) ?SequenceInfo {
    if (self._sequence_info_buff_len == 0) return null;
    var ret = self._sequence_info_buff[0];
    var len = ret.sequence_split.compute_len();

    var i: usize = 1;
    while (i < self._sequence_info_buff_len) : (i += 1) {
        const tmp = self._sequence_info_buff[i];
        const tmp_len = tmp.sequence_split.compute_len();
        if (tmp_len > len) {
            ret = tmp;
            len = tmp_len;
        }
    }
    return ret;
}

fn _build_seq_info_if_seq(
    filename_1: []const u8,
    filename_2: []const u8,
) ?SequenceInfo {
    const sequence_result_or_null = sequence_utils.check_is_sequence_using_two_filenames(
        filename_1,
        filename_2,
    );
    if (sequence_result_or_null != null) {
        const sequence_result = sequence_result_or_null.?;
        const pattern_before = filename_1[0..sequence_result.number_start_idx];
        const pattern_after = filename_2[sequence_result.number_end_idx_filename_1..];

        var ret = SequenceInfo.init();
        ret.pattern_before.append_string(pattern_before);
        ret.pattern_after.append_string(pattern_after);
        ret.sequence_split.add_value(sequence_result.seq_number_filenam_1);
        ret.sequence_split.add_value(sequence_result.seq_number_filenam_2);
        return ret;
    } else {
        return null;
    }
}

test "get_seq_info" {
    var sequence_parser = Self.init();
    var dir = try fs.cwd().openDir("tests/seq_test", .{});
    try sequence_parser.populate(&dir);
    const b = sequence_parser.get_longer_sequence();
    try std.testing.expectEqual(false, (b == null));
    try std.testing.expectEqual(
        [_]u16{ 2, 4, 10, 1, 13, 1, 16, 0, 18, 2, 22, 2, 29, 0 },
        b.?.sequence_split.array[0..14].*,
    );
    try std.testing.expectEqualSlices(
        u8,
        "089_06_surf-v001.",
        b.?.pattern_before.get_slice(),
    );
    try std.testing.expectEqualSlices(
        u8,
        ".exr",
        b.?.pattern_after.get_slice(),
    );
}
