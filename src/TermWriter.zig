const std = @import("std");
const Writer = std.fs.File.Writer;

const Self = @This();

_writer: Writer,

pub const Color = enum(u8) {
    Black = '0',
    Red = '1',
    Green = '2',
    Yellow = '3',
    Blue = '4',
    Magenta = '5',
    Cyan = '6',
    White = '7',
};

pub fn init() Self {
    return Self{
        ._writer = std.io.getStdOut().writer(),
    };
}

pub fn deinit(self: *Self) void {
    self._writer = undefined;
}

pub fn write(self: *Self, str: []const u8, color: ?Color) !void {
    if (color == null) {
        _ = try self._writer.write(str);
    } else {
        _ = try self._writer.write("\x1b[3");
        _ = try self._writer.writeByte(@intFromEnum(color.?));
        _ = try self._writer.writeByte('m');
        _ = try self._writer.write(str);
        _ = try self._writer.write("\x1b[0m");
    }
}
