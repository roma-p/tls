const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;

const sequence_split = @import("sequence_split.zig");
const sequence_parser = @import("sequence_parser.zig");
const sequence_formatter = @import("sequence_formatter.zig");
const size_formatter = @import("size_formatter.zig");
const SequenceSplit = sequence_split.SequenceSplit;
const filename_comp = @import("filename_comp.zig");
const string_on_stack = @import("string_on_stack.zig");
const StringOnStack = string_on_stack.StringOnStack;
const constants = @import("constants.zig");
const file_stat = @import("file_stat.zig");
const permission = @import("permission.zig");
const date_formatter = @import("date_formatter.zig");
const _dir_content = @import("dir_content.zig");
const DirContent = _dir_content.DirContent;

const def_entry = DirEntry{ .name = "", .kind = .file };

pub fn main() !void {
    var dir_content = DirContent.init();

    const dir = try fs.cwd().openDir(".", .{ .access_sub_paths = false, .iterate = true });
    var writer = std.io.getStdOut().writer();

    var term_str_out = StringOnStack(constants.MAX_STR_LEN_ENTRY).init();
    var seq_parser = sequence_parser.init();
    term_str_out.deinit();

    try dir_content.populate(&dir);
    const dir_content_slice = dir_content.get_slice();

    for (dir_content_slice) |entry| {
        const name_slice = entry.name.get_slice();
        if (std.mem.eql(u8, name_slice, "")) continue;

        const stat_refined = try file_stat.posix_stat(dir, name_slice);
        const size_format = size_formatter.format_size(stat_refined.size);

        term_str_out.append_string(permission.FilePermissions.format(stat_refined.mode)[0..10]);
        if (try file_stat.hasAnyExtendedAttributes(name_slice)) {
            term_str_out.append_char('@');
        } else {
            term_str_out.append_char(' ');
        }

        // max size of size if 6 char: 999.9T
        const is_size_to_print = switch (entry.kind) {
            .file => true,
            else => false,
        };

        if (is_size_to_print) {
            const size_info = size_format.@"2";
            if (size_info == 0) {
                try term_str_out.append_number(f32, size_format.@"0", 6, null);
            } else if (size_info == 1) {
                try term_str_out.append_number(f32, size_format.@"0", 5, null);
                term_str_out.append_char(size_format.@"1");
            } else {
                term_str_out.append_string("  huge");
            }
        } else {
            term_str_out.append_string("     -");
        }

        term_str_out.append_string("  ");
        term_str_out.append_string(stat_refined.owner[0..stat_refined.owner_len]);
        term_str_out.append_string("\t");

        const date_info = date_formatter.get_date_info(stat_refined.mtime);
        try term_str_out.append_number(u8, date_info.@"1", 2, null);
        term_str_out.append_char(' ');
        term_str_out.append_string(date_formatter.conv_mont_id_to_trigram(date_info.@"2"));
        term_str_out.append_char(' ');
        if (date_info.@"0" == 0) {
            try term_str_out.append_number(u8, date_info.@"4".?, 2, "2");
            term_str_out.append_char(':');
            try term_str_out.append_number(u8, date_info.@"5".?, 2, "2");
        } else {
            try term_str_out.append_number(u16, date_info.@"3".?, 4, null);
        }
        term_str_out.append_char(' ');

        term_str_out.append_string(name_slice);

        switch (entry.kind) {
            .file => {},
            .directory => {
                const d = try dir.openDir(name_slice, .{ .no_follow = false, .iterate = true });
                const is_seq = try seq_parser.get_seq_info(&d);
                if (is_seq) {
                    term_str_out.append_string(" :: ");
                    try sequence_formatter.format_sequence(
                        seq_parser.pattern_before.get_slice(),
                        seq_parser.pattern_after.get_slice(),
                        &seq_parser.sequence_split.array,
                        seq_parser.sequence_split.split_end,
                        &term_str_out,
                    );
                    seq_parser.reset();
                }
            },
            else => {},
        }
        term_str_out.append_string("\n");
        _ = try writer.write(
            term_str_out.get_slice(),
        );
        term_str_out.reset();
    }
}
