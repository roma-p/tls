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
    self.size_indicator = undefined;
    self.size = undefined;
    self.size_char = undefined;
    self.buffer_string.deinit();
    self.buffer_string = undefined;
    self.ambiguous = undefined;
}

pub fn init_from_size(number: u64) Self {
    const ko = 1_000;
    const mo = 1_000_000;
    const go = 1_000_000_000;
    const to = 1_000_000_000_000;

    const tmp_1: i128 = number;
    const tmp_2: f64 = @floatFromInt(tmp_1);

    var c: u8 = ' ';
    var tmp_3: f64 = 0;
    var size_range: u2 = 1;

    if (tmp_2 > 999 * to) {
        c = ' ';
        size_range = 2;
    } else if (tmp_2 > to) {
        c = 'T';
        tmp_3 = tmp_2 / to;
    } else if (tmp_2 > go) {
        c = 'G';
        tmp_3 = tmp_2 / go;
    } else if (tmp_2 > mo) {
        c = 'M';
        tmp_3 = tmp_2 / mo;
    } else if (tmp_2 > ko) {
        c = 'k';
        tmp_3 = tmp_2 / ko;
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
        .buffer_string = undefined,
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
    const tmp = Self.init_from_size(number);
    if (self.size_indicator != tmp.size_indicator) {
        self.ambiguous = .Different;
    } else if (self.size_char != tmp.size_char) {
        self.ambiguous = .Different;
    } else if (self.size != tmp.size) {
        self.ambiguous = .SameChar;
    } else {
        self.ambiguous = .Identical;
    }
}

pub fn display(self: *Self, writer: *TermWriter) !void {
    const is_size_to_print = true;
    if (is_size_to_print) {
        if (self.ambiguous == .Different) {
            self.buffer_string.append_string("     ?");
        } else if (self.size_indicator == 0) {
            if (self.ambiguous == .SameChar) {
                self.buffer_string.append_string("     ?");
            } else {
                self.buffer_string.append_number(f32, self.size, 6, null);
            }
        } else if (self.size_indicator == 1) {
            if (self.ambiguous == .Identical) {
                self.buffer_string.append_number(f32, self.size, 5, null);
            } else {
                self.buffer_string.append_string("    ?");
            }
            self.buffer_string.append_char(self.size_char);
        } else {
            self.buffer_string.append_string("  huge");
        }
    } else {
        self.buffer_string.append_string("     -");
    }
    try writer.write(self.buffer_string.get_slice(), TermWriter.Color.Green);
}
