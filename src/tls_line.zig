const std = @import("std");
const string = @import("string.zig");
const format_date = @import("format_date.zig");

permission: [10]u8,
has_xattr: u1,
size: Size,
owner: string.StringShortUnicode,
date: Date,
filename: string.StringLongUnicode,
extra: string.StringLongUnicode,

_string_buffer: string.StringShortAscii,

// TODO tagunion for extra: either symlink either sequence
// TODO kind? used as type for typenum?

const Date = struct {
    less_than_a_year_ago: u1,
    day: [2]u8,
    month: [3]u8,
    year_or_hour: [5]u8,

    pub fn init() Date {
        return Date{
            .less_than_a_year_ago = 0,
            .day = [_]u8{ ' ', ' ' },
            .month = [_]u8{ ' ', ' ', ' ' },
            .year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' },
        };
    }

    pub fn reset(self: *Date) void {
        self.less_than_a_year_ago = 0;
        self.day = [_]u8{ ' ', ' ' };
        self.month = [_]u8{ ' ', ' ', ' ' };
        self.year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' };
    }

    pub fn deinit(self: *Date) void {
        self.less_than_a_year_ago = undefined;
        self.day = undefined;
        self.month = undefined;
        self.year_or_hour = undefined;
    }

    pub fn init_from_epoch(
        epoch: u64,
        now: format_date.DateTime,
        string_buffer: *string.StringShortAscii,
    ) Date {
        const date = format_date.generate_datetime_from_epoch(epoch);
        const is_older_by_a_year = Date._is_date_older_by_a_year(now, date);
        var ret = Date.init();

        string_buffer.reset();
        string_buffer.append_number(date.day);
        const day_slice = string_buffer.get_slice();
        ret.day[0] = day_slice[0];
        ret.day[1] = day_slice[1];

        ret.month = format_date.conv_mont_id_to_trigram(date.month);

        string_buffer.reset();
        if (is_older_by_a_year) {
            string_buffer.append_number(date.year);
            const year_slice = string_buffer.get_slice();
            ret.year_or_hour[0] = year_slice[0];
            ret.year_or_hour[1] = year_slice[1];
            ret.year_or_hour[2] = year_slice[2];
            ret.year_or_hour[3] = year_slice[3];
            ret.year_or_hour[4] = year_slice[4];
        } else {
            string_buffer.append_number(date.hour);
            const hour_slice = string_buffer.get_slice();
            ret.year_or_hour[0] = hour_slice[0];
            ret.year_or_hour[1] = hour_slice[1];
            ret.year_or_hour[2] = ':';
            string_buffer.reset();
            string_buffer.append_number(date.minute);
            const minute_slice = string_buffer.get_slice();
            ret.year_or_hour[3] = minute_slice[0];
            ret.year_or_hour[4] = minute_slice[1];
            string_buffer.reset();
        }
        return ret;
    }

    pub fn set_from_epoch(
        self: *Date,
        epoch: u64,
        now: format_date.DateTime,
        string_buffer: *string.StringShortAscii,
    ) void {
        const tmp = Date.init_from_epoch(epoch, now, string_buffer);
        self.less_than_a_year_ago = tmp.less_than_a_year_ago;
        self.day = tmp.day;
        self.month = tmp.month;
        self.year_or_hour = tmp.year_or_hour;
    }

    fn _is_date_older_by_a_year(now: format_date.DateTime, date: format_date.DateTime) u1 {
        if (date.year == now.year) {
            return false;
        } else if (date.year + 1 < now.year) {
            return true;
        } else if (date.month < now.month) {
            return false;
        } else {
            return true;
        }
    }
};

const Size = struct {
    size_indicator: u2,
    // 0: under a ko, no letter, 1: between ko an 999 To, 2: beyound
    size: f32,
    size_char: u8,

    pub fn init() Size {
        return Size{
            .size_indicator = 0,
            .size = 0,
            .size_char = 0,
        };
    }

    pub fn reset(self: *Size) void {
        self.size_indicator = 0;
        self.size = 0;
        self.size_char = 0;
    }

    pub fn deinit(self: *Size) void {
        self.size_indicator = undefined;
        self.size = undefined;
        self.size_char = undefined;
    }

    pub fn init_from_size(number: u64) Size {
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

        return Size{
            .size_indicator = size_range,
            .size = ret,
            .size_char = c,
        };
    }

    pub fn set_from_size(self: *Size, number: u64) void {
        const tmp = Size.init_from_size(number);
        self.size_indicator = tmp.size_indicator;
        self.size = tmp.size;
        self.size_char = tmp.size_char;
    }
};

const Self = @This();

pub fn init() Self {
    return Self{
        .permission = [_]u8{' '} ** 10,
        .has_xattr = bool,
        .size = Size.init(),
        .owner = string.StringShortUnicode.init(),
        .date = Date.init(),
        .filename = string.StringLongUnicode.init(),
        .extra = string.StringLongUnicode.init(),
        ._string_buffer = string.StringShortAscii.init(),
    };
}

pub fn reset(self: *Self) void {
    self.permission = [_]u8{' '} ** 10;
    self.has_xattr = bool;
    self.size.reset();
    self.owner.reset();
    self.date.reset();
    self.filename.reset();
    self._string_buffer.reset();
    self.extra.reset();
}

pub fn deinit(self: *Self) void {
    self.permission = undefined;
    self.has_xattr = undefined;
    self.size.deinit();
    self.size = undefined;
    self.owner.deinit();
    self.owner = undefined;
    self.date.deinit();
    self.date = undefined;
    self.filename.deinit();
    self.filename = undefined;
    self._string_buffer.deinit();
    self._string_buffer = undefined;
    self.extra.deinit();
    self.extra = undefined;
}
