const std = @import("std");
const mem = std.mem;

const Self = @This();

year: u16,
month: u8,
day: u8,
hour: u8,
minute: u8,

const c = @cImport({
    @cInclude("time.h");
});

pub fn init(ts: u64) Self {
    const SECONDS_PER_DAY = 86400;
    const DAYS_PER_YEAR = 365;
    const DAYS_IN_4YEARS = 1461;
    const DAYS_IN_100YEARS = 36524;
    const DAYS_IN_400YEARS = 146097;
    const DAYS_BEFORE_EPOCH = 719468;

    var time_val: c.time_t = @intCast(ts);
    var tm: c.struct_tm = undefined;
    _ = c.localtime_r(&time_val, &tm);
    const tz_offset: i64 = tm.tm_gmtoff;
    const local_ts: u64 = @intCast(@as(i64, @intCast(ts)) + tz_offset);

    const seconds_since_midnight: u64 = @rem(local_ts, SECONDS_PER_DAY);
    var day_n: u64 = DAYS_BEFORE_EPOCH + local_ts / SECONDS_PER_DAY;
    var temp: u64 = 0;

    // Calculate century and year
    temp = 4 * (day_n + DAYS_IN_100YEARS + 1) / DAYS_IN_400YEARS - 1;
    var year: u16 = @intCast(100 * temp);
    day_n -= DAYS_IN_100YEARS * temp + temp / 4;

    // Calculate remaining years
    temp = 4 * (day_n + DAYS_PER_YEAR + 1) / DAYS_IN_4YEARS - 1;
    year += @intCast(temp);
    day_n -= DAYS_PER_YEAR * temp + temp / 4;

    // Calculate month and day
    var month: u8 = @intCast((5 * day_n + 2) / 153);
    const day: u8 = @intCast(day_n - (@as(u64, @intCast(month)) * 153 + 2) / 5 + 1);

    // Adjust month and year
    month += 3;
    if (month > 12) {
        month -= 12;
        year += 1;
    }

    // Calculate hour and minute
    const hour: u8 = @intCast(seconds_since_midnight / 3600);
    const minute: u8 = @intCast((seconds_since_midnight % 3600) / 60);

    return Self{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
    };
}

test "parse timestamp with minutes" {
    // Use localtime_r to get expected local values, same as init() does
    const timestamp: u64 = 1640995200; // January 1, 2022 00:00:00 UTC
    const dt = init(timestamp);

    var time_val: c.time_t = @intCast(timestamp);
    var tm: c.struct_tm = undefined;
    _ = c.localtime_r(&time_val, &tm);

    try std.testing.expectEqual(@as(u16, @intCast(tm.tm_year + 1900)), dt.year);
    try std.testing.expectEqual(@as(u8, @intCast(tm.tm_mon + 1)), dt.month);
    try std.testing.expectEqual(@as(u8, @intCast(tm.tm_mday)), dt.day);
    try std.testing.expectEqual(@as(u8, @intCast(tm.tm_hour)), dt.hour);
    try std.testing.expectEqual(@as(u8, @intCast(tm.tm_min)), dt.minute);
}
