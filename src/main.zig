const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;

const sequence_split = @import("sequence_split.zig");
const sequence_parser = @import("sequence_parser.zig");
const format_sequence = @import("format_sequence.zig");
const format_size = @import("format_size.zig");
const SequenceSplit = sequence_split.SequenceSplit;
const string = @import("string.zig");
const StringLongUnicode = string.StringLongUnicode;
const StringShortUnicode = string.StringShortUnicode;
const constants = @import("constants.zig");
const file_stat = @import("file_stat.zig");
const format_permission = @import("format_permission.zig");
const format_date = @import("format_date.zig");
const _dir_content = @import("dir_content.zig");
const DirContent = _dir_content.DirContent;
const tls_line = @import("tls_line.zig");

const def_entry = DirEntry{ .name = "", .kind = .file };

pub fn main() !void {
    var tls_line_instance = tls_line.init();
    defer tls_line_instance.deinit();

    var dir_content = DirContent.init();
    defer dir_content.deinit();

    const dir = try fs.cwd().openDir(".", .{ .access_sub_paths = false, .iterate = true });

    var seq_parser = sequence_parser.init();
    defer seq_parser.deinit();

    try dir_content.populate(&dir);
    const dir_content_slice = dir_content.get_slice();

    for (dir_content_slice) |entry| {
        const name_slice = entry.name.get_slice();
        if (std.mem.eql(u8, name_slice, "")) continue;

        const stat_refined = try file_stat.posix_stat(dir, name_slice);
        tls_line_instance.size.set_from_size(stat_refined.size);
        tls_line_instance.permissions.set_from_mode(stat_refined.mode);
        tls_line_instance.has_xattr = stat_refined.has_xattr;
        tls_line_instance.owner.set_string(stat_refined.owner[0..stat_refined.owner_len]);
        tls_line_instance.date.set_from_epoch(stat_refined.mtime);
        tls_line_instance.entry_name.set_string(name_slice);
        tls_line_instance.entry_kind = entry.kind;

        switch (entry.kind) {
            .file => {
                tls_line_instance.extra_type = tls_line.ExtraType.None;
            },
            .directory => {
                const d = try dir.openDir(name_slice, .{ .no_follow = false, .iterate = true });
                try seq_parser.populate(&d);
                const seq_or_null = seq_parser.get_longer_sequence();
                if (seq_or_null != null) {
                    const seq = seq_or_null.?;
                    tls_line_instance.extra_type = tls_line.ExtraType.Sequence;
                    tls_line_instance.extra.reset();
                    format_sequence.format_sequence(
                        seq.pattern_before.get_slice(),
                        seq.pattern_after.get_slice(),
                        &seq.sequence_split.array,
                        seq.sequence_split.split_end,
                        &tls_line_instance.extra,
                    );
                    seq_parser.reset();
                }
            },
            else => {
                tls_line_instance.extra_type = tls_line.ExtraType.None;
            },
        }
        try tls_line_instance.display();
        tls_line_instance.reset();
    }
}
