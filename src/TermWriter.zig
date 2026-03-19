const std = @import("std");
const File = std.fs.File;
const String = @import("data_structure/string.zig").String;

const LineBuffer = String(1024, u8);
const OUT_BUF_SIZE = 4096;

const Self = @This();

_file: File,
_line_buffer: LineBuffer,
_out_buf: [OUT_BUF_SIZE]u8,
_out_len: usize,

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
        ._file = File.stdout(),
        ._line_buffer = LineBuffer.init(),
        ._out_buf = undefined,
        ._out_len = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.* = undefined;
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
    const line = self._line_buffer.get_slice();
    if (self._out_len + line.len > OUT_BUF_SIZE) {
        try self.flush();
    }
    // If a single line exceeds the buffer, write it directly
    if (line.len > OUT_BUF_SIZE) {
        try self._file.writeAll(line);
    } else {
        @memcpy(self._out_buf[self._out_len..][0..line.len], line);
        self._out_len += line.len;
    }
    self._line_buffer.reset();
}

pub fn flush(self: *Self) !void {
    if (self._out_len > 0) {
        try self._file.writeAll(self._out_buf[0..self._out_len]);
        self._out_len = 0;
    }
}
