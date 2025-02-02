const std = @import("std");

// Structure to represent file permissions
pub const FilePermissions = struct {
    const Self = @This();

    // Convert mode to permission string
    pub fn format(mode: u32) [10]u8 {
        var buffer: [10]u8 = undefined;

        // File type
        buffer[0] = switch (mode & 0o170000) {
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
        buffer[1] = if (mode & 0o400 != 0) 'r' else '-';
        buffer[2] = if (mode & 0o200 != 0) 'w' else '-';
        buffer[3] = if (mode & 0o100 != 0) 'x' else '-';

        // Group permissions
        buffer[4] = if (mode & 0o040 != 0) 'r' else '-';
        buffer[5] = if (mode & 0o020 != 0) 'w' else '-';
        buffer[6] = if (mode & 0o010 != 0) 'x' else '-';

        // Others permissions
        buffer[7] = if (mode & 0o004 != 0) 'r' else '-';
        buffer[8] = if (mode & 0o002 != 0) 'w' else '-';
        buffer[9] = if (mode & 0o001 != 0) 'x' else '-';
        return buffer;
    }
};
