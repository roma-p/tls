const std = @import("std");
const fs = std.fs;

const sequence_split_mod = @import("sequence_split.zig");
const filename_comp = @import("filename_comp.zig");
const string_on_stack = @import("string_on_stack.zig");
const constants = @import("constants.zig");

sequence_split: sequence_split_mod.SequenceSplit,
pattern_before: string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN),
pattern_after: string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN),

const Self = @This();

pub fn init() Self {
    return Self{
        .sequence_split = sequence_split_mod.SequenceSplit.init(),
        .pattern_before = string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN).init(),
        .pattern_after = string_on_stack.StringOnStack(constants.MAX_STR_LEN_PATTERN).init(),
    };
}

pub fn reset(self: *Self) void {
    self.sequence_split.reset();
    self.pattern_before.reset();
    self.pattern_after.reset();
}

pub fn deinit(self: *Self) void {
    self.sequence_split.deinit();
    self.sequence_split = undefined;
}

// TODO: rewrite to work with useless files...
pub fn get_seq_info(self: *Self, dir: *fs.Dir) !bool {
    var first_filename: []const u8 = undefined;
    var secd_filename: []const u8 = undefined;
    var has_list_one_file_in_dir: bool = false;
    var has_list_two_file_in_dir: bool = false;

    var w = dir.iterate();

    // find the first filename used to compare to the others...
    while (try w.next()) |e| {
        switch (e.kind) {
            .file => {
                first_filename = e.name;
                has_list_one_file_in_dir = true;
                break;
            },
            else => return false,
        }
    }

    if (!has_list_one_file_in_dir) return false;

    // looking for second filename : used to look for sequence pattern.
    while (try w.next()) |e| {
        switch (e.kind) {
            .file => {
                secd_filename = e.name;
                has_list_two_file_in_dir = true;
                break;
            },
            else => return false,
        }
    }

    if (!has_list_two_file_in_dir) return false;

    const two_file_cmp_ret = try filename_comp.check_is_sequence_using_two_filenames(
        first_filename,
        secd_filename,
    );
    if (two_file_cmp_ret.@"0" == 1) return false;

    self.sequence_split.add_value(two_file_cmp_ret.@"3");
    self.sequence_split.add_value(two_file_cmp_ret.@"4");

    const pattern_before = first_filename[0..two_file_cmp_ret.@"1"];
    const pattern_after = first_filename[two_file_cmp_ret.@"2"..];

    while (try w.next()) |e| {
        switch (e.kind) {
            .file => {
                const seq_nb = try filename_comp.check_file_belong_to_sequence(
                    e.name,
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
