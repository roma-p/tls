const std = @import("std");
const fs = std.fs;

const sequence_split_mod = @import("sequence_split.zig");
const filename_comp = @import("filename_comp.zig");
const string_on_stack = @import("string_on_stack.zig");
const constants = @import("constants.zig");
const _dir_content = @import("dir_content.zig");
const DirContent = _dir_content.DirContent;

dir_content: DirContent,

sequence_split: sequence_split_mod.SequenceSplit,
pattern_before: string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN),
pattern_after: string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN),

filename_buffer_1: string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN),
filename_buffer_2: string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN),

const Self = @This();

pub fn init() Self {
    return Self{
        .dir_content = DirContent.init(),
        .sequence_split = sequence_split_mod.SequenceSplit.init(),
        .pattern_after = string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN).init(),
        .pattern_before = string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN).init(),
        .filename_buffer_1 = string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN).init(),
        .filename_buffer_2 = string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN).init(),
    };
}

pub fn reset(self: *Self) void {
    self.dir_content.reset();
    self.sequence_split.reset();
    self.pattern_before.reset();
    self.pattern_after.reset();
    self.filename_buffer_1.reset();
    self.filename_buffer_2.reset();
}

pub fn deinit(self: *Self) void {
    self.dir_content.deinit();
    self.sequence_split.deinit();
    self.pattern_before.deinit();
    self.pattern_after.deinit();
    self.filename_buffer_1.deinit();
    self.filename_buffer_2.deinit();
    self.dir_content = undefined;
    self.sequence_split = undefined;
    self.pattern_before = undefined;
    self.filename_buffer_1 = undefined;
    self.filename_buffer_2 = undefined;
}

// TODO: rewrite to work with useless files...
pub fn get_seq_info(self: *Self, dir: *const fs.Dir) !bool {
    var has_list_one_file_in_dir: bool = false;
    var has_list_two_file_in_dir: bool = false;

    self.dir_content.reset();
    self.filename_buffer_1.reset();
    self.filename_buffer_2.reset();

    try self.dir_content.populate(dir);
    const dir_content_slice = self.dir_content.get_slice();

    var i: usize = 0;

    // find the first filename used to compare to the others...
    while (i < dir_content_slice.len) {
        var e = dir_content_slice[i];
        i += 1;
        switch (e.kind) {
            .file => {
                self.filename_buffer_1.append_string(e.name.get_slice());
                has_list_one_file_in_dir = true;
                break;
            },
            else => return false,
        }
    }

    if (!has_list_one_file_in_dir) return false;

    // looking for second filename : used to look for sequence pattern.
    while (i < dir_content_slice.len) {
        var e = dir_content_slice[i];
        i += 1;
        switch (e.kind) {
            .file => {
                self.filename_buffer_2.append_string(e.name.get_slice());
                has_list_two_file_in_dir = true;
                break;
            },
            else => return false,
        }
    }

    if (!has_list_two_file_in_dir) return false;

    const first_filename = self.filename_buffer_1.get_slice();
    const secd_filename = self.filename_buffer_2.get_slice();

    const two_file_cmp_ret = try filename_comp.check_is_sequence_using_two_filenames(
        first_filename,
        secd_filename,
    );
    if (two_file_cmp_ret.@"0" == 1) return false;

    self.sequence_split.add_value(two_file_cmp_ret.@"3");
    self.sequence_split.add_value(two_file_cmp_ret.@"4");

    const pattern_before = first_filename[0..two_file_cmp_ret.@"1"];
    const pattern_after = first_filename[two_file_cmp_ret.@"2"..];

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
                    return false;
                } else {
                    self.sequence_split.add_value(seq_nb.?);
                }
            },
            else => return false,
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
