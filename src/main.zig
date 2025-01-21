const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;

const sequence_split = @import("sequence_split.zig");
const sequence_parser = @import("sequence_parser.zig");
const sequence_formatter = @import("sequence_formatter.zig");
const SequenceSplit = sequence_split.SequenceSplit;
const filename_comp = @import("filename_comp.zig");
const string_on_stack = @import("string_on_stack.zig");
const StringOnStack = string_on_stack.StringOnStack;
const constants = @import("constants.zig");

const def_entry = DirEntry{ .name = "", .kind = .file };

pub fn main() !void {
    const dir = try fs.cwd().openDir(".", .{ .access_sub_paths = false, .iterate = true });
    var walker = dir.iterate();
    var writer = std.io.getStdOut().writer();

    var term_str_out = StringOnStack(constants.MAX_STR_ENTRY_LEN).init();
    var seq_parser = sequence_parser.init();
    term_str_out.deinit();

    var dir_entry_sorted = [1]DirEntry{def_entry} ** constants.MAX_FILE_IN_DIR;

    var i: usize = 0;

    while (try walker.next()) |entry| {
        dir_entry_sorted[i] = entry;
        i += 1;
        // TODO: handle overflow.
    }

    std.mem.sort(DirEntry, &dir_entry_sorted, {}, comptime struct {
        fn lessThan(_: void, lhs: DirEntry, rhs: DirEntry) bool {
            return std.mem.order(u8, lhs.name, rhs.name) == .lt;
        }
    }.lessThan);

    for (dir_entry_sorted) |entry| {
        if (std.mem.eql(u8, entry.name, "")) continue;

        dir_entry_sorted[i] = entry;
        i += 1;
        const stat = try dir.statFile(entry.name);
        try term_str_out.append_number(u64, stat.size); // TODO format size!
        term_str_out.append_string("\t");
        term_str_out.append_string(entry.name);

        switch (entry.kind) {
            .file => {},
            .directory => {
                var d = try dir.openDir(entry.name, .{ .no_follow = false, .iterate = true });
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
