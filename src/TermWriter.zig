const std = @import("std");
const Writer = std.fs.File.Writer;
const String = @import("data_structure/string.zig").String;

const LineBuffer = String(512, u8);

const Self = @This();

_writer: Writer,
_line_buffer: LineBuffer,

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
        ._line_buffer = LineBuffer.init(),
    };
}

pub fn deinit(self: *Self) void {
    self._writer = undefined;
    self._line_buffer = undefined;
}

pub fn append_to_buffer_line(self: *Self, str: []const u8, color: ?Color) void {
    if (color == null) {
        self._line_buffer.append_string(str);
    } else {
        self._line_buffer.append_string("\x1b[3");
        self._line_buffer.append_char(@intFromEnum(color.?));
        self._line_buffer.append_char('m');
        self._line_buffer.append_string(str);
        self._line_buffer.append_string("\x1b[0m");
    }
}

pub fn write_buffer(self: *Self) !void {
    _ = try self._writer.write(self._line_buffer.get_slice());
    self._line_buffer.reset();
}
