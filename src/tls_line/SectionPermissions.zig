const TermWriter = @import("../TermWriter.zig");

const Self = @This();

permissions: [10]u8,

pub fn init() Self {
    return Self{
        .permissions = [_]u8{' '} ** 10,
    };
}

pub fn reset(self: *Self) void {
    self.permissions = [_]u8{' '} ** 10;
}

pub fn deinit(self: *Self) void {
    self.permissions = undefined;
}

pub fn set_from_mode(self: *Self, mode: u32) void {
    // File type
    self.permissions[0] = switch (mode & 0o170000) {
        0o170000 => 'b', // Block device
        0o140000 => 'l', // Symbolic link
        0o120000 => 'n', // Socket
        0o110000 => 'p', // FIFO
        0o100000 => '-', // Directory
        0o060000 => 'b', // Block device
        0o040000 => 'd', // Regular file
        0o030000 => 'c', // Character device
        else => '-',
    };

    // Owner permissions
    self.permissions[1] = if (mode & 0o400 != 0) 'r' else '-';
    self.permissions[2] = if (mode & 0o200 != 0) 'w' else '-';
    self.permissions[3] = if (mode & 0o100 != 0) 'x' else '-';

    // Group permissions
    self.permissions[4] = if (mode & 0o040 != 0) 'r' else '-';
    self.permissions[5] = if (mode & 0o020 != 0) 'w' else '-';
    self.permissions[6] = if (mode & 0o010 != 0) 'x' else '-';

    // Others permissions
    self.permissions[7] = if (mode & 0o004 != 0) 'r' else '-';
    self.permissions[8] = if (mode & 0o002 != 0) 'w' else '-';
    self.permissions[9] = if (mode & 0o001 != 0) 'x' else '-';
}

pub fn display(self: *Self, writer: *TermWriter) !void {
    for (self.permissions) |c| {
        const r: []const u8 = &[1]u8{c};
        const color: TermWriter.Color = switch (c) {
            'r' => .Yellow,
            'w' => .Red,
            'x' => .Green,
            'd' => .Blue,
            else => .White,
        };
        _ = try writer.write(r, color);
    }
}
