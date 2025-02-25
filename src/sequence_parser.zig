const std = @import("std");
const fs = std.fs;

const sequence_split_mod = @import("sequence_split.zig");
const filename_comp = @import("filename_comp.zig");
const string = @import("string.zig");
const constants = @import("constants.zig");
const _dir_content = @import("dir_content.zig");
const DirContent = _dir_content.DirContent;

_dir_content: DirContent,
// _sequence_info_buff: [100]SequenceInfo,

sequence_split: sequence_split_mod.SequenceSplit,
pattern_before: string.StringLongUnicode,
pattern_after: string.StringLongUnicode,

// missing here: multiple sequences. flag to capture or not rights.

const SequenceInfo = struct {
    sequence_split: sequence_split_mod.SequenceSplit,
    pattern_after: string.StringLongUnicode,
    pattern_before: string.StringLongUnicode,
};

const Self = @This();

pub fn init() Self {
    return Self{
        ._dir_content = DirContent.init(),
        .sequence_split = sequence_split_mod.SequenceSplit.init(),
        .pattern_after = string.StringLongUnicode.init(),
        .pattern_before = string.StringLongUnicode.init(),
    };
}

pub fn reset(self: *Self) void {
    self._dir_content.reset();
    self.sequence_split.reset();
    self.pattern_before.reset();
    self.pattern_after.reset();
}

pub fn deinit(self: *Self) void {
    self._dir_content.deinit();
    self.sequence_split.deinit();
    self.pattern_before.deinit();
    self.pattern_after.deinit();
    self._dir_content = undefined;
    self.sequence_split = undefined;
    self.pattern_before = undefined;
}

pub fn get_seq_info(self: *Self, dir: *const fs.Dir) !bool {
    self._dir_content.reset();
    try self._dir_content.populate(dir);
    const dir_content_slice = self._dir_content.get_slice();

    if (dir_content_slice.len == 0) return false;

    var entry_buffer_1: DirContent.DirEntry = dir_content_slice[0];
    var entry_buffer_2: DirContent.DirEntry = undefined;

    var is_sequence_found = false;
    var has_extra_file = false; // TODO: use me

    var i: usize = 1;

    // find the first filename used to compare to the others...
    while (i < dir_content_slice.len) {
        const e = dir_content_slice[i];
        i += 1;
        switch (e.kind) {
            .file => {
                entry_buffer_2 = e;

                const filename_1 = entry_buffer_1.name.get_slice();
                const filename_2 = entry_buffer_2.name.get_slice();

                const two_file_cmp_ret = try filename_comp.check_is_sequence_using_two_filenames(
                    filename_1,
                    filename_2,
                );

                if (two_file_cmp_ret.@"0" == 0) {
                    is_sequence_found = true;
                    break;
                } else {
                    entry_buffer_1 = entry_buffer_2;
                    has_extra_file = true;
                }
            },
            else => continue,
        }
    }

    if (!is_sequence_found) return false;

    const filename_1 = entry_buffer_1.name.get_slice();
    const filename_2 = entry_buffer_2.name.get_slice();

    // default
    const two_file_cmp_ret = try filename_comp.check_is_sequence_using_two_filenames(
        filename_1,
        filename_2,
    );

    self.sequence_split.add_value(two_file_cmp_ret.@"3");
    self.sequence_split.add_value(two_file_cmp_ret.@"4");

    const pattern_before = filename_1[0..two_file_cmp_ret.@"1"];
    const pattern_after = filename_2[two_file_cmp_ret.@"2"..];

    while (i < dir_content_slice.len) {
        var e = dir_content_slice[i];
        i += 1;
        switch (e.kind) {
            .file => {
                const seq_nb = try filename_comp.check_file_belong_to_sequence(
                    e.name.get_slice(),
                    pattern_before,
                    pattern_after,
                );
                if (seq_nb == null) {
                    continue;
                } else {
                    self.sequence_split.add_value(seq_nb.?);
                }
            },
            else => continue,
        }
    }

    self.pattern_after.append_string(pattern_after);
    self.pattern_before.append_string(pattern_before);
    return true;
}

test "get_seq_info" {
    var sequence_parser = Self.init();
    var dir = try fs.cwd().openDir("tests/seq_test", .{});
    const b = try sequence_parser.get_seq_info(&dir);
    try std.testing.expectEqual(true, b);
    try std.testing.expectEqual(
        [_]u16{ 2, 4, 10, 1, 13, 1, 16, 0, 18, 2, 22, 2, 29, 0 },
        sequence_parser.sequence_split.array[0..14].*,
    );
    try std.testing.expectEqualSlices(
        u8,
        "089_06_surf-v001.",
        sequence_parser.pattern_before.get_slice(),
    );
    try std.testing.expectEqualSlices(
        u8,
        ".exr",
        sequence_parser.pattern_after.get_slice(),
    );

    // TODO: test me !
}
