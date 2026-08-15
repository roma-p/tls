const std = @import("std");
const string = @import("../data_structure/string.zig");
const TermWriter = @import("../TermWriter.zig");

const Self = @This();

size_indicator: u2, // 0: under a ko, no letter, 1: between ko an 999 To, 2: beyound
size: f32, // TODO: store as string buff to print more precise "?"
size_char: u8,
buffer_string: SizeBufferString,
ambiguous: Ambiguous,

const SizeBufferString = string.String(6, u8);

const Ambiguous = enum {
    Identical,
    SameChar,
    Different,
};

pub fn init() Self {
    return Self{
        .size_indicator = 0,
        .size = 0,
        .size_char = 0,
        .buffer_string = SizeBufferString.init(),
        .ambiguous = .Identical,
    };
}

pub fn reset(self: *Self) void {
    self.size_indicator = 0;
    self.size = 0;
    self.size_char = 0;
    self.buffer_string.reset();
    self.ambiguous = .Identical;
}

pub fn deinit(self: *Self) void {
    self.* = undefined;
}

pub fn init_from_size(number: u64) Self {
    const kb = 1_000;
    const mb = 1_000_000;
    const gb = 1_000_000_000;
    const tb = 1_000_000_000_000;

    const tmp_1: i128 = number;
    const tmp_2: f64 = @floatFromInt(tmp_1);

    var c: u8 = ' ';
    var tmp_3: f64 = 0;
    var size_range: u2 = 1;

    if (tmp_2 > 999 * tb) {
        c = ' ';
        size_range = 2;
    } else if (tmp_2 > tb) {
        c = 'T';
        tmp_3 = tmp_2 / tb;
    } else if (tmp_2 > gb) {
        c = 'G';
        tmp_3 = tmp_2 / gb;
    } else if (tmp_2 > mb) {
        c = 'M';
        tmp_3 = tmp_2 / mb;
    } else if (tmp_2 > kb) {
        c = 'k';
        tmp_3 = tmp_2 / kb;
    } else {
        c = ' ';
        size_range = 0;
        tmp_3 = tmp_2;
    }
    var ret: f32 = @floatCast(tmp_3);
    ret = @round(ret * 10) / 10;

    return Self{
        .size_indicator = size_range,
        .size = ret,
        .size_char = c,
        .buffer_string = SizeBufferString.init(),
        .ambiguous = .Identical,
    };
}

pub fn set_from_size(self: *Self, number: u64) void {
    const tmp = Self.init_from_size(number);
    self.size_indicator = tmp.size_indicator;
    self.size = tmp.size;
    self.size_char = tmp.size_char;
    self.ambiguous = tmp.ambiguous;
}

pub fn update_from_size(self: *Self, number: u64) void {
    if (self.ambiguous == .Different) return;
    const tmp = Self.init_from_size(number);
    if (self.size_indicator != tmp.size_indicator) {
        self.ambiguous = .Different;
    } else if (self.size_char != tmp.size_char) {
        self.ambiguous = .Different;
    } else if (self.size != tmp.size) {
        self.ambiguous = .SameChar;
    }
}

pub fn natural_len(number: u64) usize {
    var tmp = Self.init_from_size(number);
    tmp.buffer_string.reset();
    tmp._append_natural();
    return tmp.buffer_string.get_slice().len;
}

fn _append_natural(self: *Self) void {
    if (self.size_indicator == 0) {
        self.buffer_string.append_number(f32, self.size, null, null);
    } else if (self.size_indicator == 1) {
        self.buffer_string.append_number(f32, self.size, null, null);
        self.buffer_string.append_char(self.size_char);
    } else {
        self.buffer_string.append_string("huge");
    }
}

pub fn display(self: *Self, writer: *TermWriter, max_len: usize) !void {
    self.buffer_string.reset();
    if (self.ambiguous == .Different) {
        self.buffer_string.append_char('?');
    } else if (self.size_indicator == 0 and self.ambiguous == .SameChar) {
        self.buffer_string.append_char('?');
    } else if (self.size_indicator == 1 and self.ambiguous != .Identical) {
        self.buffer_string.append_char('?');
        self.buffer_string.append_char(self.size_char);
    } else {
        self._append_natural();
    }

    const content = self.buffer_string.get_slice();
    var i: usize = content.len;
    while (i < max_len) : (i += 1) writer.append_to_buffer_line(" ", null);
    writer.append_to_buffer_line(content, TermWriter.Color.Green);
}
