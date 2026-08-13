const std = @import("std");
const DateTime = @import("../DateTime.zig");
const TermWriter = @import("../TermWriter.zig");

const Self = @This();

_date: DateTime,
_now: DateTime,
less_than_a_year_ago: bool,
ambiguous: Ambiguous,

const Ambiguous = enum(u3) {
    None = 0,
    Minute = 1,
    Hour = 2,
    Day = 3,
    Month = 4,
    Year = 5,
};

pub fn init() Self {
    return Self{
        ._date = .{ .year = 1970, .month = 1, .day = 1, .hour = 0, .minute = 0 },
        ._now = DateTime.init(std.time.timestamp()),
        .less_than_a_year_ago = false,
        .ambiguous = .None,
    };
}

pub fn reset(self: *Self) void {
    self.ambiguous = .None;
}

pub fn deinit(self: *Self) void {
    self.* = undefined;
}

pub fn set_from_epoch(self: *Self, epoch: i64) void {
    self._date = DateTime.init(epoch);
    self.less_than_a_year_ago = !_is_date_older_by_a_year(self._now, self._date);
    self.ambiguous = .None;
}

pub fn update_from_epoch(self: *Self, epoch: i64) void {
    self._update_from_date(DateTime.init(epoch));
}

fn _update_from_date(self: *Self, other: DateTime) void {
    const level = _diff_level(self._date, other);
    if (@intFromEnum(level) > @intFromEnum(self.ambiguous)) {
        self.ambiguous = level;
    }
}

pub fn display(self: *Self, writer: *TermWriter) !void {
    const color = TermWriter.Color.Blue;
    var buf: [8]u8 = undefined;

    if (self._is_unknown(.Day)) {
        writer.append_to_buffer_line(" ?", color);
    } else {
        const day = std.fmt.bufPrint(&buf, "{d: >2}", .{self._date.day}) catch " ?";
        writer.append_to_buffer_line(day, color);
    }
    writer.append_to_buffer_line(" ", null);

    if (self._is_unknown(.Month)) {
        writer.append_to_buffer_line("  ?", color);
    } else {
        writer.append_to_buffer_line(_conv_mont_id_to_trigram(self._date.month), color);
    }
    writer.append_to_buffer_line(" ", null);

    if (self.less_than_a_year_ago) {
        if (self._is_unknown(.Hour)) {
            writer.append_to_buffer_line("??:??", color);
        } else if (self._is_unknown(.Minute)) {
            const t = std.fmt.bufPrint(&buf, "{d:0>2}:??", .{self._date.hour}) catch "??:??";
            writer.append_to_buffer_line(t, color);
        } else {
            const t = std.fmt.bufPrint(
                &buf,
                "{d:0>2}:{d:0>2}",
                .{ self._date.hour, self._date.minute },
            ) catch "??:??";
            writer.append_to_buffer_line(t, color);
        }
    } else {
        if (self._is_unknown(.Year)) {
            writer.append_to_buffer_line("    ?", color);
        } else {
            const y = std.fmt.bufPrint(&buf, "{d: <5}", .{self._date.year}) catch "    ?";
            writer.append_to_buffer_line(y, color);
        }
    }
}

fn _is_unknown(self: *const Self, level: Ambiguous) bool {
    return @intFromEnum(self.ambiguous) >= @intFromEnum(level);
}

fn _diff_level(a: DateTime, b: DateTime) Ambiguous {
    if (a.year != b.year) return .Year;
    if (a.month != b.month) return .Month;
    if (a.day != b.day) return .Day;
    if (a.hour != b.hour) return .Hour;
    if (a.minute != b.minute) return .Minute;
    return .None;
}

fn _is_date_older_by_a_year(now: DateTime, date: DateTime) bool {
    if (date.year == now.year) {
        return false;
    } else if (date.year + 1 < now.year) {
        return true;
    } else {
        // date.year + 1 == now.year: compare month then day
        if (date.month > now.month) {
            return false;
        } else if (date.month < now.month) {
            return true;
        } else {
            return date.day <= now.day;
        }
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

///////////////////////////////////////////////////////////////////////////////

test "diff_level picks the highest differing component" {
    const a = DateTime{ .year = 2026, .month = 8, .day = 13, .hour = 10, .minute = 15 };

    var b = a;
    try std.testing.expectEqual(Ambiguous.None, _diff_level(a, b));
    b.minute = 25;
    try std.testing.expectEqual(Ambiguous.Minute, _diff_level(a, b));
    b = a;
    b.hour = 11;
    try std.testing.expectEqual(Ambiguous.Hour, _diff_level(a, b));
    b = a;
    b.day = 14;
    try std.testing.expectEqual(Ambiguous.Day, _diff_level(a, b));
    b = a;
    b.month = 9;
    try std.testing.expectEqual(Ambiguous.Month, _diff_level(a, b));
    b = a;
    b.year = 2019;
    b.minute = 15;
    try std.testing.expectEqual(Ambiguous.Year, _diff_level(a, b));
}

test "ambiguity latches to the worst level seen" {
    var section = Self.init();
    section._date = DateTime{ .year = 2026, .month = 8, .day = 13, .hour = 10, .minute = 15 };
    section.ambiguous = .None;

    var other = section._date;
    other.day = 14;
    section._update_from_date(other);
    try std.testing.expectEqual(Ambiguous.Day, section.ambiguous);

    section._update_from_date(section._date);
    try std.testing.expectEqual(Ambiguous.Day, section.ambiguous);

    try std.testing.expect(section._is_unknown(.Hour));
    try std.testing.expect(section._is_unknown(.Day));
    try std.testing.expect(!section._is_unknown(.Month));
}
