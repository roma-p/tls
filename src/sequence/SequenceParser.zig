const std = @import("std");
const FileKind = std.fs.File.Kind;
const SequenceInfo = @import("SequenceInfo.zig");
const SequenceInfoArray = @import("SequenceInfoArray.zig");
const sequence_utils = @import("sequence_utils.zig");
const DirContent = @import("../file_structure/DirContent.zig");
const DirEntry = DirContent.DirEntry;
const StringLong = @import("../data_structure/string.zig").StringLong;

const Self = @This();

sequence_info_array: *SequenceInfoArray,

_dir_entry_slice: []const DirEntry,
_dir_entry_buff_1: DirEntry, // TODO: make this pointer.
_dir_entry_buff_2: DirEntry, // TODO: make this pointer.
_dir_entry_curr: DirEntry,
_i: usize, // use for dir_entry_slice
_j: usize, // use for sequence_info_array.array
_parsing_seq_state: ParsingSeqState,

const ParsingSeqState = enum {
    LookingForSequence,
    ParsingSequence,
};

pub fn init() Self {
    return Self{
        .sequence_info_array = undefined,
        ._dir_entry_slice = undefined,
        ._dir_entry_buff_1 = undefined,
        ._dir_entry_buff_2 = undefined,
        ._dir_entry_curr = undefined,
        ._i = undefined,
        ._j = undefined,
        ._parsing_seq_state = undefined,
    };
}

pub fn deinit(self: *Self) void {
    self.* = undefined;
}

pub fn reset(self: *Self) void {
    self.sequence_info_array = undefined;
    self._dir_entry_slice = undefined;
    self._dir_entry_buff_1 = undefined;
    self._dir_entry_buff_2 = undefined;
    self._dir_entry_curr = undefined;
    self._i = undefined;
    self._j = undefined;
    self._parsing_seq_state = undefined;
}

pub fn parse_sequence(
    self: *Self,
    dir_entry_slice: []const DirEntry,
    sequence_info_array: *SequenceInfoArray,
) !void {
    self.reset();
    self.sequence_info_array = sequence_info_array;
    self.sequence_info_array.reset();

    self._i = 1;
    self._j = 0;

    if (dir_entry_slice.len < 2) return;

    self._dir_entry_slice = dir_entry_slice;

    self._dir_entry_buff_1 = dir_entry_slice[0];
    self._dir_entry_buff_2 = undefined;
    self._parsing_seq_state = ParsingSeqState.LookingForSequence;

    while (self._i < self._dir_entry_slice.len) {
        self._dir_entry_curr = self._dir_entry_slice[self._i];
        self._i += 1;
        switch (self._parsing_seq_state) {
            .LookingForSequence => try self._state_looking_for_sequence(),
            .ParsingSequence => try self._state_parsing_sequence(),
        }
    }

    if (self._parsing_seq_state == ParsingSeqState.ParsingSequence) self._j += 1;
    self.sequence_info_array.array_seq_info.len = self._j;

    for (self.sequence_info_array.array_seq_info.get_slice()) |seq_info| {
        try self.sequence_info_array.array_seq_start_idx.append(seq_info.idx_start);
    }
    std.mem.sort(
        usize,
        self.sequence_info_array.array_seq_start_idx.array[0..self.sequence_info_array.array_seq_start_idx.len],
        {},
        comptime std.sort.asc(usize),
    );
}

fn _state_looking_for_sequence(self: *Self) !void {
    switch (self._dir_entry_curr.kind) {
        .file, .unknown => {
            self._dir_entry_buff_2 = self._dir_entry_curr;
            const tmp = _build_seq_info_if_seq(
                self._dir_entry_buff_1.name.get_slice(),
                self._dir_entry_buff_2.name.get_slice(),
                self._i - 2,
            );
            if (tmp != null) {
                try self.sequence_info_array.array_seq_info.ensureCapacity(self._j + 1);
                self.sequence_info_array.array_seq_info.array[self._j] = tmp.?;
                self._parsing_seq_state = ParsingSeqState.ParsingSequence;
            } else {
                self._dir_entry_buff_1 = self._dir_entry_buff_2;
                self.sequence_info_array.has_extra_file = true;
            }
        },
        else => {
            self.sequence_info_array.has_extra_file = true;
        },
    }
}

fn _state_parsing_sequence(self: *Self) !void {
    var finish_parsing_sequence = false;
    var last = &self.sequence_info_array.array_seq_info.array[self._j];
    switch (self._dir_entry_curr.kind) {
        .file, .unknown => {
            const seq_nb = sequence_utils.check_file_belong_to_sequence(
                self._dir_entry_curr.name.get_slice(),
                last.pattern_before.get_slice(),
                last.pattern_after.get_slice(),
            );
            if (seq_nb == null) {
                finish_parsing_sequence = true;
            } else {
                last.sequence_split.add_value(seq_nb.?);
            }
        },
        else => {
            finish_parsing_sequence = true;
        },
    }
    if (finish_parsing_sequence) {
        self._j += 1;
        self._parsing_seq_state = ParsingSeqState.LookingForSequence;
        try self._state_looking_for_sequence();
    }
}
fn _build_seq_info_if_seq(
    filename_1: []const u8,
    filename_2: []const u8,
    i_start: usize,
) ?SequenceInfo {
    const sequence_result_or_null = sequence_utils.check_is_sequence_using_two_filenames(
        filename_1,
        filename_2,
    );

    if (sequence_result_or_null == null) return null;

    const sequence_result = sequence_result_or_null.?;
    const pattern_before = filename_1[0..sequence_result.number_start_idx];
    const pattern_after = filename_2[sequence_result.number_end_idx_filename_1..];

    var ret = SequenceInfo.init();
    ret.pattern_before.append_string(pattern_before);
    ret.pattern_after.append_string(pattern_after);
    ret.sequence_split.add_value(sequence_result.seq_number_filename_1);
    ret.sequence_split.add_value(sequence_result.seq_number_filename_2);
    ret.idx_start = i_start;
    return ret;
}

test "seq_1" {
    var dir_content = try DirContent.init(std.testing.allocator);
    defer dir_content.deinit();

    const content_dir = [_][]const u8{
        "0039_1830-ani-blocking2-v001.ma",
        "0039_1830-ani-blocking2-v002.ma",
        "0039_1830-ani-blocking-v001.ma",
        "0039_1830-ani-blocking-v002.ma",
        "0039_1830-ani-blocking-v003.ma",
        "0039_1830-ani-blocking-v004.ma",
        "0039_1830-ani-blocking-v005.ma",
        "0039_1830-ani-debug-v002.ma",
        "0039_1830-ani-polish-v000.ma",
        "0039_1830-ani-polish-v001.ma",
        "0039_1830-ani-polish-v002.ma",
        "0039_1830-ani-polish-v003.ma",
        "0039_1830-ani-spline-v001.ma",
        "0039_1830-ani-spline-v002.ma",
        "0039_1830-ani-spline-v003.ma",
        "debug_1.exr",
        "debug_2.exr",
        "maya_crash_report.json",
    };

    for (content_dir) |de| {
        try dir_content.dir_entry_array.append(DirEntry{
            .name = StringLong.init_from_slice(de),
            .kind = .file,
        });
    }

    var sequence_array = try SequenceInfoArray.init(std.testing.allocator);
    defer sequence_array.deinit();
    var sequence_parser = Self.init();
    try sequence_parser.parse_sequence(dir_content.get_slice(), &sequence_array);

    // Should detect 5 sequences: blocking2(2), blocking(5), polish(4), spline(3), debug(2)
    try std.testing.expectEqual(@as(usize, 5), sequence_array.array_seq_info.len);

    // blocking2: v001-v002
    const seq_0 = sequence_array.array_seq_info.array[0];
    try std.testing.expectEqualSlices(u8, "0039_1830-ani-blocking2-v", seq_0.pattern_before.get_slice());
    try std.testing.expectEqualSlices(u8, ".ma", seq_0.pattern_after.get_slice());
    try std.testing.expectEqual(@as(usize, 2), seq_0.sequence_split.compute_len());

    // blocking: v001-v005
    const seq_1 = sequence_array.array_seq_info.array[1];
    try std.testing.expectEqualSlices(u8, "0039_1830-ani-blocking-v", seq_1.pattern_before.get_slice());
    try std.testing.expectEqual(@as(usize, 5), seq_1.sequence_split.compute_len());

    // polish: v000-v003
    const seq_2 = sequence_array.array_seq_info.array[2];
    try std.testing.expectEqualSlices(u8, "0039_1830-ani-polish-v", seq_2.pattern_before.get_slice());
    try std.testing.expectEqual(@as(usize, 4), seq_2.sequence_split.compute_len());

    // spline: v001-v003
    const seq_3 = sequence_array.array_seq_info.array[3];
    try std.testing.expectEqualSlices(u8, "0039_1830-ani-spline-v", seq_3.pattern_before.get_slice());
    try std.testing.expectEqual(@as(usize, 3), seq_3.sequence_split.compute_len());

    // debug: 1-2
    const seq_4 = sequence_array.array_seq_info.array[4];
    try std.testing.expectEqualSlices(u8, "debug_", seq_4.pattern_before.get_slice());
    try std.testing.expectEqualSlices(u8, ".exr", seq_4.pattern_after.get_slice());
    try std.testing.expectEqual(@as(usize, 2), seq_4.sequence_split.compute_len());
}

test "seq_lion_render" {
    var dir_content = try DirContent.init(std.testing.allocator);
    defer dir_content.deinit();

    const base = "210_lion_010-dgc-cut01-v002-rec709.";
    const ext = ".jpg";
    var buf: [256]u8 = undefined;

    // Add frames 1103-1200
    var frame: u16 = 1103;
    while (frame <= 1200) : (frame += 1) {
        const name = std.fmt.bufPrint(&buf, "{s}{d}{s}", .{ base, frame, ext }) catch unreachable;
        try dir_content.dir_entry_array.append(DirEntry{
            .name = StringLong.init_from_slice(name),
            .kind = .file,
        });
    }

    var sequence_array = try SequenceInfoArray.init(std.testing.allocator);
    defer sequence_array.deinit();
    var sequence_parser = Self.init();
    try sequence_parser.parse_sequence(dir_content.get_slice(), &sequence_array);

    // Should detect 1 sequence of 98 frames
    std.debug.print("\nDetected sequences: {d}\n", .{sequence_array.array_seq_info.len});
    for (sequence_array.array_seq_info.array[0..sequence_array.array_seq_info.len], 0..) |seq, i| {
        std.debug.print("  seq[{d}]: {s}[...]{s} len={d}\n", .{
            i,
            seq.pattern_before.get_slice(),
            seq.pattern_after.get_slice(),
            seq.sequence_split.compute_len(),
        });
    }

    try std.testing.expectEqual(@as(usize, 1), sequence_array.array_seq_info.len);
    const seq = sequence_array.array_seq_info.array[0];
    try std.testing.expectEqualSlices(u8, "210_lion_010-dgc-cut01-v002-rec709.", seq.pattern_before.get_slice());
    try std.testing.expectEqualSlices(u8, ".jpg", seq.pattern_after.get_slice());
    try std.testing.expectEqual(@as(usize, 98), seq.sequence_split.compute_len());
}

test "seq_empty_and_single" {
    var dir_content = try DirContent.init(std.testing.allocator);
    defer dir_content.deinit();

    var sequence_array = try SequenceInfoArray.init(std.testing.allocator);
    defer sequence_array.deinit();
    var sequence_parser = Self.init();

    // Empty directory
    try sequence_parser.parse_sequence(dir_content.get_slice(), &sequence_array);
    try std.testing.expectEqual(@as(usize, 0), sequence_array.array_seq_info.len);

    // Single file
    try dir_content.dir_entry_array.append(DirEntry{
        .name = StringLong.init_from_slice("single_file.exr"),
        .kind = .file,
    });
    try sequence_parser.parse_sequence(dir_content.get_slice(), &sequence_array);
    try std.testing.expectEqual(@as(usize, 0), sequence_array.array_seq_info.len);
}
