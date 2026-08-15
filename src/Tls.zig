const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;
const format_sequence = @import("tls_line/format_sequence.zig");
const string = @import("data_structure/string.zig");

const constants = @import("constants.zig");
const FileStat = @import("file_structure/FileStat.zig");
const SequenceInfo = @import("sequence/SequenceInfo.zig");
const SequenceInfoArray = @import("sequence/SequenceInfoArray.zig");
const SequenceParser = @import("sequence/SequenceParser.zig");
const DirContent = @import("file_structure/DirContent.zig");
const SectionSize = @import("tls_line/SectionSize.zig");
const TlsLine = @import("tls_line/TlsLine.zig");

const Self = @This();

dir_content_cur_dir: DirContent,
dir_content_sub_dir: DirContent,

sequence_parser: SequenceParser,
sequence_info_array_cur_dir: SequenceInfoArray,
sequence_info_array_sub_dir: SequenceInfoArray,

tls_line: TlsLine,

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .dir_content_cur_dir = try DirContent.init(allocator),
        .dir_content_sub_dir = try DirContent.init(allocator),
        .sequence_parser = SequenceParser.init(),
        .sequence_info_array_cur_dir = try SequenceInfoArray.init(allocator),
        .sequence_info_array_sub_dir = try SequenceInfoArray.init(allocator),
        .tls_line = TlsLine.init(),
    };
}

pub fn deinit(self: *Self) void {
    self.dir_content_cur_dir.deinit();
    self.dir_content_sub_dir.deinit();
    self.sequence_info_array_cur_dir.deinit();
    self.sequence_info_array_sub_dir.deinit();
    self.* = undefined;
}

pub fn process(self: *Self, path: []const u8) !void {
    var dir_fs = try fs.cwd().openDir(path, .{ .access_sub_paths = false, .iterate = true });
    defer dir_fs.close();

    try self.dir_content_cur_dir.populate(&dir_fs, true);
    self.tls_line._max_owner_len = self.dir_content_cur_dir.max_owner_len;
    self.tls_line._max_size_len = self._compute_max_size_len();
    try self.sequence_parser.parse_sequence(&self.dir_content_cur_dir, &self.sequence_info_array_cur_dir);
    self._set_extra_alignment_width();

    var walk = Walk{
        .dir_fs = &dir_fs,
        .dir_content_cur = &self.dir_content_cur_dir,
        .dir_content_sub = &self.dir_content_sub_dir,
        .parser = &self.sequence_parser,
        .seq_cur = &self.sequence_info_array_cur_dir,
        .seq_sub = &self.sequence_info_array_sub_dir,
        .tls_line = &self.tls_line,
        .dir_entry_slice = self.dir_content_cur_dir.get_slice(),
        .f_stat_slice = self.dir_content_cur_dir.file_stat_array.get_slice(),
    };
    try walk.run();
}

fn _set_extra_alignment_width(self: *Self) void {
    var counts = [_]usize{0} ** (string.MAX_STR_LEN_ENTRY + 1);
    for (self.dir_content_cur_dir.get_slice()) |*entry| {
        switch (entry.kind) {
            .sym_link, .directory => {
                counts[entry.name_len] += 1;
            },
            else => {},
        }
    }

    var anchor: usize = 0;
    var i: usize = counts.len;
    while (i > 0) {
        i -= 1;
        if (counts[i] == 0) continue;
        anchor = i;
        if (counts[i] > 1) break;
        var next: usize = i;
        var next_found = false;
        var j: usize = i;
        while (j > 0) {
            j -= 1;
            if (counts[j] != 0) {
                next = j;
                next_found = true;
                break;
            }
        }
        if (!next_found) break;
        if (i - next <= constants.MAX_EXTRA_PADDING) break;
        i = next + 1;
    }
    self.tls_line._max_extra_name_len = anchor;
}

fn _compute_max_size_len(self: *Self) usize {
    var max_len: usize = 1;
    const entries = self.dir_content_cur_dir.get_slice();
    const stats = self.dir_content_cur_dir.file_stat_array.get_slice();
    for (entries, stats) |entry, stat| {
        if (entry.kind == .directory) continue;
        const w = SectionSize.natural_len(stat.size);
        if (w > max_len) max_len = w;
    }
    return max_len;
}

const Walk = struct {
    dir_fs: *fs.Dir,
    dir_content_cur: *DirContent,
    dir_content_sub: *DirContent,
    parser: *SequenceParser,
    seq_cur: *SequenceInfoArray,
    seq_sub: *SequenceInfoArray,
    tls_line: *TlsLine,

    dir_entry_slice: []const DirContent.DirEntry,
    f_stat_slice: []const FileStat,
    idx: usize = 0,
    state: State = .OutSequence,
    curr_seq_idx: usize = 0,
    curr_seq_start_idx: usize = 0,
    curr_seq_end_idx: usize = 0,
    seq_nbr: usize = 0,
    has_sequence: bool = false,

    const State = enum {
        OutSequence,
        FirstElem,
        InSequence,
        LastElem,
    };

    fn run(self: *Walk) !void {
        self.seq_nbr = self.seq_cur.array_seq_start_idx.len;
        self.has_sequence = self.seq_nbr > 0;
        if (self.has_sequence) {
            self.update_seq_start_stop();
            if (self.is_in_sequence()) self.state = .FirstElem;
        }

        while (self.idx < self.dir_entry_slice.len) : (self.idx += 1) {
            try self.process_single_entry();
            switch (self.state) {
                .OutSequence => self.state_outside_sequence(),
                .FirstElem => self.state_first_elem(),
                .InSequence => self.state_in_sequence(),
                .LastElem => self.state_last_elem(),
            }
        }
        try self.tls_line._term_writer.flush();
    }

    fn state_outside_sequence(self: *Walk) void {
        if (self.is_entering_sequence()) {
            self.state = .FirstElem;
        }
    }

    fn state_first_elem(self: *Walk) void {
        self.state = switch (self.is_leaving_sequence()) {
            true => .LastElem,
            false => .InSequence,
        };
    }

    fn state_in_sequence(self: *Walk) void {
        if (self.is_leaving_sequence()) {
            self.state = .LastElem;
        }
    }

    fn state_last_elem(self: *Walk) void {
        self.increment_seq_iterator();
        self.update_seq_start_stop();
        self.state = switch (self.is_entering_sequence()) {
            true => .FirstElem,
            false => .OutSequence,
        };
    }

    fn is_entering_sequence(self: *Walk) bool {
        return (self.idx + 1 == self.curr_seq_start_idx);
    }

    fn is_in_sequence(self: *Walk) bool {
        return (self.idx >= self.curr_seq_start_idx and
            self.idx < self.curr_seq_end_idx);
    }

    fn is_leaving_sequence(self: *Walk) bool {
        return (self.idx + 2 == self.curr_seq_end_idx);
    }

    fn increment_seq_iterator(self: *Walk) void {
        if (!self.has_sequence) {
            return;
        } else if (self.curr_seq_idx + 1 == self.seq_nbr) {
            self.has_sequence = false;
        } else {
            self.curr_seq_idx += 1;
        }
    }

    fn update_seq_start_stop(self: *Walk) void {
        self.curr_seq_start_idx = self.seq_cur.array_seq_start_idx.array[self.curr_seq_idx];
        const seq_len = self.seq_cur.array_seq_info.array[self.curr_seq_idx].sequence_split.compute_len();
        self.curr_seq_end_idx = self.curr_seq_start_idx + seq_len;
    }

    fn process_single_entry(self: *Walk) !void {
        const entry = self.dir_entry_slice[self.idx];
        const fstat = self.f_stat_slice[self.idx];

        self.tls_line.extra = .{ .None = {} };

        switch (self.state) {
            .OutSequence => self.set_tls_line(&entry, fstat),
            .FirstElem => self.set_tls_line(&entry, fstat),
            .InSequence => self.update_tls_line(fstat),
            .LastElem => self.update_tls_line(fstat),
        }
        switch (entry.kind) {
            .file => {
                self.tls_line.extra_type = TlsLine.ExtraType.None;
            },
            .sym_link => {
                var target_buf: [std.fs.max_path_bytes]u8 = undefined;
                const target = self.dir_fs.readLink(
                    self.dir_content_cur.get_entry_name(entry),
                    &target_buf,
                ) catch "?";

                self.tls_line.extra_type = TlsLine.ExtraType.Symlink;
                self.tls_line.extra = .{ .Symlink = .{
                    .target = string.StringLong.init_from_slice(target),
                    .target_exists = if (self.dir_fs.access(target, .{})) true else |_| false,
                } };
            },
            .directory => {
                try self.process_single_dir();
            },
            else => {
                self.tls_line.extra_type = TlsLine.ExtraType.None;
            },
        }

        if (self.state == .OutSequence or self.state == .LastElem) {
            if (self.state == .LastElem) self.set_tls_line_filename_seq();
            try self.tls_line.display();
            self.tls_line.reset();
        }
    }

    fn process_single_dir(self: *Walk) !void {
        const entry = self.dir_entry_slice[self.idx];
        var d = self.dir_fs.openDir(
            self.dir_content_cur.get_entry_name(entry),
            .{ .no_follow = false, .iterate = true },
        ) catch {
            return;
        };
        defer d.close();

        try self.dir_content_sub.populate(&d, false);
        try self.parser.parse_sequence(self.dir_content_sub, self.seq_sub);

        const seq_or_null = self.seq_sub.get_longer_sequence();
        if (seq_or_null != null) {
            const seq = seq_or_null.?;
            self.tls_line.extra_type = TlsLine.ExtraType.Sequence;
            self.tls_line.extra.reset();
            self.tls_line.extra = .{ .Sequence = string.StringLong.init() };
            format_sequence.format_sequence(
                seq.pattern_before.get_slice(),
                seq.pattern_after.get_slice(),
                &seq.sequence_split.array,
                seq.sequence_split.split_end,
                &self.tls_line.extra.Sequence,
            );
        } else {
            self.tls_line.extra_type = TlsLine.ExtraType.None;
        }
    }

    fn set_tls_line_filename_seq(self: *Walk) void {
        self.tls_line.entry_name.reset();
        const seq = self.seq_cur.array_seq_info.array[self.curr_seq_idx];
        format_sequence.format_sequence(
            seq.pattern_before.get_slice(),
            seq.pattern_after.get_slice(),
            &seq.sequence_split.array,
            seq.sequence_split.split_end,
            &self.tls_line.entry_name,
        );
    }

    fn set_tls_line(self: *Walk, entry: *const DirContent.DirEntry, stat_refined: FileStat) void {
        self.tls_line.permissions.set_from_mode(stat_refined.mode);
        self.tls_line.has_xattr = stat_refined.has_xattr;
        self.tls_line.size.set_from_size(stat_refined.size);
        self.tls_line.owner.set_string(self.dir_content_cur.resolve_owner(stat_refined.uid));
        self.tls_line.date.set_from_epoch(stat_refined.mtime);
        self.tls_line.entry_name.set_string(self.dir_content_cur.get_entry_name(entry.*));
        self.tls_line.entry_kind = entry.kind;
        self.tls_line.ext = stat_refined.ext;
    }

    fn update_tls_line(self: *Walk, stat_refined: FileStat) void {
        self.tls_line.size.update_from_size(stat_refined.size);
        self.tls_line.update_owner(self.dir_content_cur.resolve_owner(stat_refined.uid));
        self.tls_line.permissions.update_from_mode(stat_refined.mode);
        self.tls_line.date.update_from_epoch(stat_refined.mtime);
    }
};
