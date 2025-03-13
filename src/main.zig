const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;

const SequenceSplit = @import("sequence/SequenceSplit.zig");
const sequence_parser = @import("sequence/sequence_parser.zig");
const format_sequence = @import("tls_line/format_sequence.zig");
const string = @import("data_structure/string.zig");
const StringLongUnicode = string.StringLongUnicode;
const StringShortUnicode = string.StringShortUnicode;
const constants = @import("constants.zig");
const file_stat = @import("file_structure/file_stat.zig");
const DirContent = @import("file_structure/DirContent.zig");
const TlsLine = @import("tls_line/TlsLine.zig");

const def_entry = DirEntry{ .name = "", .kind = .file };

fn set_tls_line(entry: *const DirContent.DirEntry, tls_line_instance: *TlsLine, stat_refined: file_stat.StatRefined) void {
    tls_line_instance.size.set_from_size(stat_refined.size);
    tls_line_instance.permissions.set_from_mode(stat_refined.mode);
    tls_line_instance.has_xattr = stat_refined.has_xattr;
    tls_line_instance.owner.set_string(stat_refined.owner[0..stat_refined.owner_len]);
    tls_line_instance.date.set_from_epoch(stat_refined.mtime);
    tls_line_instance.entry_name.set_string(entry.name.get_slice());
    tls_line_instance.entry_kind = entry.kind;
}

pub fn main() !void {
    var tls_line_instance = TlsLine.init();
    defer tls_line_instance.deinit();

    var dir_content_curr = DirContent.init();
    defer dir_content_curr.deinit();

    var dir_content_sub = DirContent.init();
    defer dir_content_sub.deinit();

    const dir = try fs.cwd().openDir(".", .{ .access_sub_paths = false, .iterate = true });

    var seq_parser_sub_dir = sequence_parser.init();
    defer seq_parser_sub_dir.deinit();

    var seq_parser_curr_dir = sequence_parser.init();
    defer seq_parser_curr_dir.deinit();
    try seq_parser_curr_dir.populate(&dir_content_curr); // TODO: seq_parser: remove DirContent: created from outside.

    try dir_content_curr.populate(&dir);
    const dir_content_slice = dir_content_curr.get_slice();

    for (dir_content_slice) |entry| {
        const name_slice = entry.name.get_slice();
        const stat_refined = try file_stat.posix_stat(dir, name_slice);

        set_tls_line(&entry, &tls_line_instance, stat_refined);

        switch (entry.kind) {
            .file => {
                tls_line_instance.extra_type = TlsLine.ExtraType.None;
            },
            .directory => {
                const d = try dir.openDir(name_slice, .{ .no_follow = false, .iterate = true });
                try dir_content_sub.populate(&d);
                try seq_parser_sub_dir.populate(&dir_content_sub);
                const seq_or_null = seq_parser_sub_dir.get_longer_sequence();
                if (seq_or_null != null) {
                    const seq = seq_or_null.?;
                    tls_line_instance.extra_type = TlsLine.ExtraType.Sequence;
                    tls_line_instance.extra.reset();
                    format_sequence.format_sequence(
                        seq.pattern_before.get_slice(),
                        seq.pattern_after.get_slice(),
                        &seq.sequence_split.array,
                        seq.sequence_split.split_end,
                        &tls_line_instance.extra,
                    );
                    seq_parser_sub_dir.reset();
                } else {
                    tls_line_instance.extra_type = TlsLine.ExtraType.None;
                }
            },
            else => {
                tls_line_instance.extra_type = TlsLine.ExtraType.None;
            },
        }
        try tls_line_instance.display();
        tls_line_instance.reset();
    }
}
