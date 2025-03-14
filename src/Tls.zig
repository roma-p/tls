const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;
const format_sequence = @import("tls_line/format_sequence.zig"); // TODO: rework this module

const FileStat = @import("file_structure/FileStat.zig"); // TODO: rework this module
const SequenceInfoArray = @import("sequence/SequenceInfoArray.zig");
const SequenceParser = @import("sequence/SequenceParser.zig");
const DirContent = @import("file_structure/DirContent.zig");
const TlsLine = @import("tls_line/TlsLine.zig");

const Self = @This();

dir_fs: fs.Dir,
dir_content_cur_dir: DirContent,
dir_content_sub_dir: DirContent,

sequence_parser: SequenceParser,
sequence_info_array_cur_dir: SequenceInfoArray,
sequence_info_array_sub_dir: SequenceInfoArray,

tls_line: TlsLine,

_dir_entry_slice: []const DirContent.DirEntry,
_dir_entry_idx: usize,

_state: State,
_curr_seq_idx: usize,
_curr_seq_start_idx: usize,
_curr_seq_end_idx: usize,
_seq_nbr: usize,
_has_sequence: bool,

const State = enum {
    InSequence,
    OutSequence,
};

pub fn init() Self {
    return Self {
        .dir_fs = undefined,
        .dir_content_cur_dir = DirContent.init(),
        .dir_content_sub_dir = DirContent.init(),
        .sequence_parser = SequenceParser.init(),
        .sequence_info_array_cur_dir = SequenceInfoArray.init(),
        .sequence_info_array_sub_dir = SequenceInfoArray.init(),
        .tls_line = TlsLine.init(),
        ._dir_entry_slice = undefined,
        ._dir_entry_idx = 0,
        ._state = undefined,
        ._curr_seq_idx = undefined,
        ._curr_seq_start_idx = undefined,
        ._curr_seq_end_idx = undefined,
        ._seq_nbr = undefined,
        ._has_sequence = undefined,
    };
}

pub fn deinit(self: *Self) void {
    self.dir_content_cur_dir.deinit();
    self.dir_content_sub_dir.deinit();
    self.sequence_parser.deinit();
    self.sequence_info_array_cur_dir.deinit();
    self.sequence_info_array_sub_dir.deinit();
    self.tls_line.deinit();
}

pub fn process(self: *Self) !void {

    self.dir_fs = try fs.cwd().openDir(".", .{ .access_sub_paths = false, .iterate = true });

    try self.dir_content_cur_dir.populate(&self.dir_fs);
    self.sequence_parser.parse_sequence(
        self.dir_content_cur_dir.get_slice(),
        &self.sequence_info_array_cur_dir
    );

    const seq_nbr = self.sequence_parser.sequence_info_array._array_seq_start_idx.len;
    if (seq_nbr == 0) {
        self._has_sequence = false;
        self._state = .OutSequence;
    } else {
        self._update_state_and_seq_iterator();
    }

    self._dir_entry_slice = self.dir_content_cur_dir.get_slice();
    self._dir_entry_idx = 0;

    while (self._dir_entry_idx < self._dir_entry_slice.len) : (self._dir_entry_idx += 1) {
        try self._process_single_entry();
    }
}

fn _update_state_and_seq_iterator(self: *Self) void {
    if (self._state == .OutSequence) {
        if (!self._has_sequence) return;
        if (self._dir_entry_idx < self._curr_seq_start_idx) return;
        self._state = .InSequence;
    } else {
        if (self._dir_entry_idx <= self._curr_seq_end_idx) return;
        self._state = .OutSequence;
        self._curr_seq_idx += 1;
        self._update_seq_iterator();
    }
}

fn _update_seq_iterator(self: *Self) void {
    if (self._curr_seq_idx == self._seq_nbr) {
        self._has_sequence = false;
        return;
    }
    self._curr_seq_start_idx = self.sequence_info_array_cur_dir._array_seq_start_idx.array[self._curr_seq_idx];
    self._curr_seq_end_idx = self._curr_seq_start_idx + self.sequence_info_array_cur_dir._array_seq_info.array[self._curr_seq_idx].sequence_split.compute_len();
}


fn _process_single_entry(self: *Self) !void {
    const entry = self._dir_entry_slice[self._dir_entry_idx];
    const stat_refined = try FileStat.init(
        self.dir_fs,
        entry.name.get_slice()
    );
    self._set_tls_line(&entry, stat_refined);

    switch (entry.kind) {
        .file => {
            self.tls_line.extra_type = TlsLine.ExtraType.None;
        },
        .directory => {
            try self._process_single_dir();
        },
        else => {
            self.tls_line.extra_type = TlsLine.ExtraType.None;
        },
    }
    try self.tls_line.display();
    self.tls_line.reset();
}

fn _process_single_dir(self: *Self) !void {
    const entry = self._dir_entry_slice[self._dir_entry_idx];
    const d = try self.dir_fs.openDir(
        entry.name.get_slice(),
        .{ .no_follow = false, .iterate = true }
    );

    try self.dir_content_sub_dir.populate(&d);
    self.sequence_parser.parse_sequence(
        self.dir_content_sub_dir.get_slice(), 
        &self.sequence_info_array_sub_dir,
    );

    const seq_or_null = self.sequence_info_array_sub_dir.get_longer_sequence();
    if (seq_or_null != null) {
        const seq = seq_or_null.?;
        self.tls_line.extra_type = TlsLine.ExtraType.Sequence;
        self.tls_line.extra.reset();
        format_sequence.format_sequence(
            seq.pattern_before.get_slice(),
            seq.pattern_after.get_slice(),
            &seq.sequence_split.array,
            seq.sequence_split.split_end,
            &self.tls_line.extra,
        );
    } else {
        self.tls_line.extra_type = TlsLine.ExtraType.None;
    }
}

fn _set_tls_line(
        self: *Self,
        entry: *const DirContent.DirEntry,
        stat_refined: FileStat,
) void {
    self.tls_line.permissions.set_from_mode(stat_refined.mode);
    self.tls_line.has_xattr = stat_refined.has_xattr;
    self.tls_line.size.set_from_size(stat_refined.size);
    self.tls_line.owner.set_string(stat_refined.owner.get_slice());
    self.tls_line.date.set_from_epoch(stat_refined.mtime);
    self.tls_line.entry_name.set_string(entry.name.get_slice());
    self.tls_line.entry_kind = entry.kind;
}

fn _update_tls_line(
        self: *Self,
        // entry: *const DirContent.DirEntry,
        stat_refined: FileStat
) void {
    self.tls_line.size.update_from_size(stat_refined.mode);
}
