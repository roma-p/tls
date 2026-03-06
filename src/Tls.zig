const std = @import("std");
const fs = std.fs;
const DirEntry = fs.Dir.Entry;
const format_sequence = @import("tls_line/format_sequence.zig"); // TODO: rework this module

const FileStat = @import("file_structure/FileStat.zig");
const SequenceInfo = @import("sequence/SequenceInfo.zig");
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

_f_stat_slice: []const FileStat,
_dir_entry_slice: []const DirContent.DirEntry,
_dir_entry_idx: usize,

_state: State,
_curr_seq_idx: usize,
_curr_seq_start_idx: usize,
_curr_seq_end_idx: usize,
_seq_nbr: usize,
_has_sequence: bool,

const State = enum {
    OutSequence,
    FirstElem,
    InSequence,
    LastElem,
};

pub fn init() Self {
    return Self{
        .dir_fs = undefined,
        .dir_content_cur_dir = DirContent.init(),
        .dir_content_sub_dir = DirContent.init(),
        .sequence_parser = SequenceParser.init(),
        .sequence_info_array_cur_dir = SequenceInfoArray.init(),
        .sequence_info_array_sub_dir = SequenceInfoArray.init(),
        .tls_line = TlsLine.init(),
        ._f_stat_slice = undefined,
        ._dir_entry_slice = undefined,
        ._dir_entry_idx = undefined,
        ._state = undefined,
        ._curr_seq_idx = undefined,
        ._curr_seq_start_idx = undefined,
        ._curr_seq_end_idx = undefined,
        ._seq_nbr = undefined,
        ._has_sequence = undefined,
    };
}

pub fn deinit(self: *Self) void {
    self.* = undefined;
}

pub fn process(self: *Self, path: []const u8) !void {
    self.dir_fs = try fs.cwd().openDir(path, .{ .access_sub_paths = false, .iterate = true });

    try self.dir_content_cur_dir.populate(&self.dir_fs, true);
    self.tls_line._max_owner_len = self.dir_content_cur_dir.max_owner_len;
    self.sequence_parser.parse_sequence(self.dir_content_cur_dir.get_slice(), &self.sequence_info_array_cur_dir);

    self._dir_entry_idx = 0;
    self._dir_entry_slice = self.dir_content_cur_dir.get_slice();
    self._f_stat_slice = self.dir_content_cur_dir.file_stat_array.get_slice();

    const seq_nbr = self.sequence_parser.sequence_info_array.array_seq_start_idx.len;
    self._curr_seq_idx = 0;
    self._state = .OutSequence;
    self._has_sequence = if (seq_nbr == 0) false else true;
    if (self._has_sequence) {
        self._update_seq_start_stop();
        if (self._is_in_sequence()) {
            self._state = .FirstElem;
        }
    }

    while (self._dir_entry_idx < self._dir_entry_slice.len) : (self._dir_entry_idx += 1) {
        try self._process_single_entry();
        switch (self._state) {
            .OutSequence => self._state_outside_sequence(),
            .FirstElem => self._state_first_elem(),
            .InSequence => self._state_in_sequence(),
            .LastElem => self._state_last_elem(),
        }
    }
    try self.tls_line._term_writer.flush();
}

fn _state_outside_sequence(self: *Self) void {
    if (self._is_enterring_sequence()) {
        self._state = .FirstElem;
    }
}

fn _state_first_elem(self: *Self) void {
    self._state = switch (self._is_leaving_sequence()) {
        true => .LastElem,
        false => .InSequence,
    };
}

fn _state_in_sequence(self: *Self) void {
    if (self._is_leaving_sequence()) {
        self._state = .LastElem;
    }
}

fn _state_last_elem(self: *Self) void {
    self._increment_seq_iterator();
    self._update_seq_start_stop();
    self._state = switch (self._is_enterring_sequence()) {
        true => .FirstElem,
        false => .OutSequence,
    };
}

fn _is_enterring_sequence(self: *Self) bool {
    return (self._dir_entry_idx + 1 == self._curr_seq_start_idx);
}

fn _is_in_sequence(self: *Self) bool {
    return (self._dir_entry_idx >= self._curr_seq_start_idx and
        self._dir_entry_idx < self._curr_seq_end_idx);
}

fn _is_leaving_sequence(self: *Self) bool {
    return (self._dir_entry_idx + 2 == self._curr_seq_end_idx);
}

fn _increment_seq_iterator(self: *Self) void {
    if (!self._has_sequence) {
        return;
    } else if (self._curr_seq_idx + 1 == self._seq_nbr) {
        self._has_sequence = false;
    } else {
        self._curr_seq_idx += 1;
    }
}

fn _update_seq_start_stop(self: *Self) void {
    self._curr_seq_start_idx = self.sequence_info_array_cur_dir.array_seq_start_idx.array[self._curr_seq_idx];
    const seq_len = self.sequence_info_array_cur_dir.array_seq_info.array[self._curr_seq_idx].sequence_split.compute_len();
    self._curr_seq_end_idx = self._curr_seq_start_idx + seq_len;
}

fn _process_single_entry(self: *Self) !void {
    const entry = self._dir_entry_slice[self._dir_entry_idx];
    const fstat = self._f_stat_slice[self._dir_entry_idx];

    switch (self._state) {
        .OutSequence => self._set_tls_line(&entry, fstat),
        .FirstElem => self._set_tls_line(&entry, fstat),
        .InSequence => self._update_tls_line(fstat),
        .LastElem => self._update_tls_line(fstat),
    }
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

    if (self._state == .OutSequence or self._state == .LastElem) {
        if (self._state == .LastElem) self._set_tls_line_filename_seq();
        try self.tls_line.display();
        self.tls_line.reset();
    }
}

fn _process_single_dir(self: *Self) !void {
    const entry = self._dir_entry_slice[self._dir_entry_idx];
    var d = self.dir_fs.openDir(
        entry.name.get_slice(),
        .{ .no_follow = false, .iterate = true },
    ) catch {
        return;
    };

    try self.dir_content_sub_dir.populate(&d, false);
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

fn _set_tls_line_filename_seq(
    self: *Self,
) void {
    self.tls_line.entry_name.reset();
    const seq = self.sequence_info_array_cur_dir.array_seq_info.array[self._curr_seq_idx];
    format_sequence.format_sequence(
        seq.pattern_before.get_slice(),
        seq.pattern_after.get_slice(),
        &seq.sequence_split.array,
        seq.sequence_split.split_end,
        &self.tls_line.entry_name,
    );
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

fn _update_tls_line(self: *Self, stat_refined: FileStat) void {
    self.tls_line.size.update_from_size(stat_refined.size);
    self.tls_line.update_owner(&stat_refined.owner);
    self.tls_line.permissions.update_from_mode(stat_refined.mode);
    self.tls_line.date.update_from_epoch(stat_refined.mtime);
}
