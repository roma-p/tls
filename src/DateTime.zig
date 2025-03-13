const std = @import("std");
const mem = std.mem;

const Self = @This();

year: u16,
month: u8,
day: u8,
hour: u8,
minute: u8,

pub fn init(ts: u64) Self {
    const SECONDS_PER_DAY = 86400;
    const DAYS_PER_YEAR = 365;
    const DAYS_IN_4YEARS = 1461;
    const DAYS_IN_100YEARS = 36524;
    const DAYS_IN_400YEARS = 146097;
    const DAYS_BEFORE_EPOCH = 719468;

    const seconds_since_midnight: u64 = @rem(ts, SECONDS_PER_DAY);
    var day_n: u64 = DAYS_BEFORE_EPOCH + ts / SECONDS_PER_DAY;
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
    const timestamp = 1640995200; // January 1, 2022 00:00:00 UTC
    const dt = init(timestamp);

    try std.testing.expectEqual(@as(u16, 2022), dt.year);
    try std.testing.expectEqual(@as(u8, 1), dt.month); // January
    try std.testing.expectEqual(@as(u8, 1), dt.day);
    try std.testing.expectEqual(@as(u8, 0), dt.hour);
    try std.testing.expectEqual(@as(u8, 0), dt.minute);
}
