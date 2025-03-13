const std = @import("std");
const fs = std.fs;
const Writer = fs.File.Writer;
const FileKind = fs.File.Kind;
const string = @import("../data_structure/string.zig");
const zig_utils = @import("../zig_utils.zig");
const TermWriter = @import("../TermWriter.zig");
const SectionDate = @import("SectionDate.zig");
const SectionSize = @import("SectionSize.zig");

const Self = @This();

permissions: Permissions,
has_xattr: bool,
size: SectionSize,
owner: string.StringShortUnicode,
date: SectionDate,
entry_name: string.StringLongUnicode,
entry_kind: FileKind,
extra: string.StringLongUnicode,
extra_type: ExtraType,
// TODO: has_extra_file

_string_buffer: string.StringShortAscii,
_term_writer: TermWriter,

pub const ExtraType = enum {
    None,
    Sequence,
    Symlink,
};


const Permissions = struct {
    permissions: [10]u8,

    pub fn init() Permissions {
        return Permissions{
            .permissions = [_]u8{' '} ** 10,
        };
    }

    pub fn reset(self: *Permissions) void {
        self.permissions = [_]u8{' '} ** 10;
    }

    pub fn deinit(self: *Permissions) void {
        self.permissions = undefined;
    }

    pub fn set_from_mode(self: *Permissions, mode: u32) void {
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

    pub fn display(self: *Permissions, writer: *TermWriter) !void {
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
};


pub fn init() Self {
    return Self{
        .permissions = Permissions.init(),
        .has_xattr = false,
        .size = SectionSize.init(),
        .owner = string.StringShortUnicode.init(),
        .date = SectionDate.init(),
        .entry_name = string.StringLongUnicode.init(),
        .entry_kind = undefined,
        .extra = string.StringLongUnicode.init(),
        .extra_type = undefined,
        ._string_buffer = string.StringShortAscii.init(),
        ._term_writer = TermWriter.init(),
    };
}

pub fn reset(self: *Self) void {
    self.permissions.reset();
    self.has_xattr = false;
    self.size.reset();
    self.owner.reset();
    self.date.reset();
    self.entry_name.reset();
    self.entry_name = undefined;
    self._string_buffer.reset();
    self.extra.reset();
    self.extra = undefined;
}

pub fn deinit(self: *Self) void {
    self.permissions.deinit();
    self.permissions = undefined;
    self.has_xattr = undefined;
    self.size.deinit();
    self.size = undefined;
    self.owner.deinit();
    self.owner = undefined;
    self.date.deinit();
    self.date = undefined;
    self.entry_name.deinit();
    self.entry_name = undefined;
    self.entry_name = undefined;
    self._string_buffer.deinit();
    self._string_buffer = undefined;
    self._term_writer.deinit();
    self._term_writer = undefined;
    self.extra.deinit();
    self.extra = undefined;
    self.extra_type = undefined;
}

pub fn display_owner(self: *Self) !void {
    try self._term_writer.write(self.owner.get_slice(), TermWriter.Color.Yellow);
}

pub fn display_xtattr(self: *Self) !void {
    if (self.has_xattr) {
        _ = try self._term_writer.write("@", TermWriter.Color.Green);
    } else {
        _ = try self._term_writer.write(" ", null);
    }
}

pub fn display_entry_name(self: *Self) !void {
    const c: TermWriter.Color = switch (self.entry_kind) {
        .directory => .Blue,
        else => .White,
    };
    try self._term_writer.write(self.entry_name.get_slice(), c);
}

pub fn display_sequence(self: *Self) !void {
    try self._term_writer.write(" :: ", TermWriter.Color.White);
    try self._term_writer.write(self.extra.get_slice(), TermWriter.Color.Cyan);
}

pub fn display(self: *Self) !void {
    const term_writer_ref = &self._term_writer;
    try self.permissions.display(term_writer_ref);
    try self.display_xtattr();
    try self._term_writer.write(" ", null);
    try self.size.display(term_writer_ref);
    try self._term_writer.write(" ", null);
    try self.display_owner();
    try self._term_writer.write(" ", null);
    try self.date.display(term_writer_ref);
    try self._term_writer.write(" ", null);
    try self.display_entry_name();

    switch (self.extra_type) {
        .None => {},
        .Symlink => unreachable,
        .Sequence => try self.display_sequence(),
    }
    try self._term_writer.write("\n", null);
}
