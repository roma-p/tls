const std = @import("std");
const string = @import("../data_structure/string.zig");
const DateTime = @import("../DateTime.zig");
const zig_utils = @import("../zig_utils.zig");
const TermWriter = @import("../TermWriter.zig");

const Self = @This();

less_than_a_year_ago: u1,
day: DayString,
month: [3]u8,
year_or_hour: [5]u8,
ambiguous: Ambiguous,
_now: DateTime,
_string_buffer: string.StringShortAscii,

const DayString = string.String(2, u8);

const Ambiguous = enum {
    UnknownYear,
    UnknownMonth,
    UnknownDay,
    OnlyHourMayDiffer,
};

pub fn init() Self {
    return Self{
        .less_than_a_year_ago = 0,
        .day = DayString.init(),
        .month = [_]u8{ ' ', ' ', ' ' },
        .year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' },
        .ambiguous = .OnlyHourMayDiffer,
        ._now = DateTime.init(@intCast(std.time.timestamp())),
        ._string_buffer = string.StringShortAscii.init(),
    };
}

pub fn reset(self: *Self) void {
    self.less_than_a_year_ago = 0;
    self.day.reset();
    self.month = [_]u8{ ' ', ' ', ' ' };
    self.year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' };
    self.ambiguous = .OnlyHourMayDiffer;
}

pub fn deinit(self: *Self) void {
    self.less_than_a_year_ago = undefined;
    self.day.deinit();
    self.day = undefined;
    self.month = undefined;
    self.year_or_hour = undefined;
    self.ambiguous = undefined;
    self._now = undefined;
    self._string_buffer.deinit();
    self._string_buffer = undefined;
}

pub fn init_from_epoch(
    epoch: u64,
    now: DateTime,
    string_buffer: *string.StringShortAscii,
) Self {
    const date = DateTime.init(epoch);
    const is_older_by_a_year = Self._is_date_older_by_a_year(now, date);
    var ret = Self.init();

    string_buffer.reset();
    string_buffer.append_number(u8, date.day, 2, null);
    const day_slice = string_buffer.get_slice();

    ret.day.set_string(day_slice);

    const month_tmp = _conv_mont_id_to_trigram(date.month);
    zig_utils.copy_arr(u8, month_tmp, &ret.month, 3);

    string_buffer.reset();
    if (is_older_by_a_year) {
        string_buffer.append_number(u16, date.year, null, null);
        string_buffer.copy_to_arr(&ret.year_or_hour, null);
    } else {
        string_buffer.append_number(u8, date.hour, null, 2);
        string_buffer.copy_to_arr(&ret.year_or_hour, null);
        ret.year_or_hour[2] = ':';
        string_buffer.reset();
        string_buffer.append_number(u8, date.minute, null, 2);
        string_buffer.copy_to_arr(&ret.year_or_hour, 3);
        string_buffer.reset();
    }
    return ret;
}

pub fn set_from_epoch(
    self: *Self,
    epoch: u64,
) void {
    const tmp = Self.init_from_epoch(epoch, self._now, &self._string_buffer);
    self.less_than_a_year_ago = tmp.less_than_a_year_ago;
    self.day = tmp.day;
    self.month = tmp.month;
    self.year_or_hour = tmp.year_or_hour;
}

pub fn update_from_epoch(self: *Self, epoch: u64) void {
    const other = Self.init_from_epoch(epoch, self._now, &self._string_buffer);
    var tmp = self.check_diff_year(&other);
    if (!tmp) tmp = self.check_diff_month(&other);
    if (!tmp) tmp = self.check_diff_day(&other);
    if (!tmp) tmp = self.check_diff_hour(&other);

    switch (self.ambiguous) {
        .UnknownYear => {
            self.set_unknown_month();
            self.set_unknown_day();
            self.set_unknown_hour();
        },
        .UnknownMonth => {
            self.set_unknown_month();
            self.set_unknown_day();
            self.set_unknown_hour();
        },
        .UnknownDay => {
            self.set_unknown_hour();
        },
        else => {},
    }
}

fn set_unknown_month(self: *Self) void {
    self.month = [_]u8{ ' ', ' ', '?' };
}

fn set_unknown_day(self: *Self) void {
    self.day.set_string(" ?");
}

fn set_unknown_hour(self: *Self) void {
    self.year_or_hour = [_]u8{ '?', '?', ':', '?', '?' };
}

fn check_diff_year(self: *Self, other: *const Self) bool {
    var diff_year = false;
    if (self.less_than_a_year_ago == 1) {
        if (other.less_than_a_year_ago == 0) {
            diff_year = true;
        } else {
            var i: usize = 1;
            while (i < 4) : (i += 1) {
                if (!diff_year and self.year_or_hour[i] != other.year_or_hour[i]) {
                    diff_year = true;
                }
                if (diff_year) {
                    self.year_or_hour[i] = '?';
                }
            }
        }
    }
    if (diff_year) {
        self.ambiguous = .UnknownYear;
    }
    return diff_year;
}

fn check_diff_month(self: *Self, other: *const Self) bool {
    var diff_month = false;
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        if (self.month[i] != other.month[i]) {
            diff_month = true;
            break;
        }
    }
    if (diff_month) {
        self.ambiguous = .UnknownMonth;
    }
    return diff_month;
}

fn check_diff_day(self: *Self, other: *const Self) bool {
    var diff_day = false;
    var j: usize = 0;
    while (j < 2) : (j += 1) {
        if (!diff_day and self.day._array.array[j] != other.day._array.array[j]) {
            diff_day = true;
        }
        if (diff_day) {
            self.day._array.array[j] = '?';
        }
    }
    if (diff_day) {
        self.ambiguous = .UnknownDay;
    }
    return diff_day;
}

fn check_diff_hour(self: *Self, other: *const Self) bool {
    var diff_hour = false;
    var k: usize = 0;
    while (k < 5) : (k += 1) {
        if (k == 2) continue;

        if (!diff_hour and self.year_or_hour[k] != other.year_or_hour[k]) {
            diff_hour = true;
        }
        if (diff_hour) {
            self.year_or_hour[k] = '?';
        }
    }
    return diff_hour;
}

pub fn display(self: *Self, writer: *TermWriter) !void {
    const c = TermWriter.Color.Blue;
    writer.append_to_buffer_line(self.day.get_slice(), c);
    writer.append_to_buffer_line(" ", null);
    writer.append_to_buffer_line(&self.month, c);
    writer.append_to_buffer_line(" ", null);
    writer.append_to_buffer_line(&self.year_or_hour, c);
}

fn _is_date_older_by_a_year(now: DateTime, date: DateTime) bool {
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

fn _conv_mont_id_to_trigram(month_id: u8) []const u8 {
    return switch (month_id) {
        1 => "Jan",
        2 => "Feb",
        3 => "Mar",
        4 => "Apr",
        5 => "May",
        6 => "Jun",
        7 => "Jul",
        8 => "Aug",
        9 => "Sep",
        10 => "Oct",
        11 => "Nov",
        12 => "Dec",
        else => "Dec", // FIXME: handle err here?
    };
}
