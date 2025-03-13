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
_now: DateTime,
_string_buffer: string.StringShortAscii,

const DayString = string.String(2, u8);

pub fn init() Self {
    return Self{
        .less_than_a_year_ago = 0,
        .day = DayString.init(),
        .month = [_]u8{ ' ', ' ', ' ' },
        .year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' },
        ._now = DateTime.init(@intCast(std.time.timestamp())),
        ._string_buffer = string.StringShortAscii.init(),
    };
}

pub fn reset(self: *Self) void {
    self.less_than_a_year_ago = 0;
    self.day.reset();
    self.month = [_]u8{ ' ', ' ', ' ' };
    self.year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' };
}

pub fn deinit(self: *Self) void {
    self.less_than_a_year_ago = undefined;
    self.day.deinit();
    self.day = undefined;
    self.month = undefined;
    self.year_or_hour = undefined;
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
    // TODO: copy helper... whith len...

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

pub fn display(self: *Self, writer: *TermWriter) !void {
    const c = TermWriter.Color.Blue;
    try writer.write(self.day.get_slice(), c);
    try writer.write(" ", null);
    try writer.write(&self.month, c);
    try writer.write(" ", null);
    try writer.write(&self.year_or_hour, c);
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

