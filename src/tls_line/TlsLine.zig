const std = @import("std");
const fs = std.fs;
const Writer = fs.File.Writer;
const FileKind = fs.File.Kind;
const string = @import("../data_structure/string.zig");
const zig_utils = @import("../zig_utils.zig");
const TermWriter = @import("../TermWriter.zig");
const SectionDate = @import("SectionDate.zig");
const SectionSize = @import("SectionSize.zig");
const SectionPermissions = @import("SectionPermissions.zig");

const Self = @This();

permissions: SectionPermissions,
has_xattr: bool,
size: SectionSize,
owner: string.StringShortUnicode,
date: SectionDate,
entry_name: string.StringLongUnicode,
entry_kind: FileKind,
extra: ExtraData,
extra_type: ExtraType,
// TODO: has_extra_file

_string_buffer: string.StringShortAscii,
_term_writer: TermWriter,
_max_owner_len: usize,

pub const ExtraType = enum {
    None,
    Sequence,
    Symlink,
};

pub const ExtraData = union(ExtraType) {
    None: void,
    Sequence: string.StringLongUnicode,
    Symlink:  struct {
        target: string.StringLongUnicode,
        target_exists: bool,
    },

    pub fn reset(self: *ExtraData) void {
        switch (self.*) {
            .None => {},
            .Sequence => |*seq| seq.reset(),
            .Symlink => |*symlink| {
                symlink.target.reset();
                symlink.target_exists = false;
            },

        }
    }
};

pub fn init() Self {
    return Self{
        .permissions = SectionPermissions.init(),
        .has_xattr = false,
        .size = SectionSize.init(),
        .owner = string.StringShortUnicode.init(),
        .date = SectionDate.init(),
        .entry_name = string.StringLongUnicode.init(),
        .entry_kind = undefined,
        .extra = undefined,
        .extra_type = undefined,
        ._string_buffer = string.StringShortAscii.init(),
        ._term_writer = TermWriter.init(),
        ._max_owner_len = 0,
    };
}

pub fn reset(self: *Self) void {
    self.permissions.reset();
    self.has_xattr = false;
    self.size.reset();
    self.owner.reset();
    self.date.reset();
    self.entry_name.reset();
    self._string_buffer.reset();
    self.extra.reset();
}

pub fn deinit(self: *Self) void {
    self.* = undefined;
}

pub fn display_owner(self: *Self) !void {
    if (self._max_owner_len > self.owner._array.len) {
        var i: usize = 0;
        const max_padding = self._max_owner_len - self.owner._array.len;
        while (i < max_padding) : (i += 1) {
            self.owner.append_char(' ');
        }
    }
    self._term_writer.append_to_buffer_line(self.owner.get_slice(), TermWriter.Color.Yellow);
}

pub fn display_xtattr(self: *Self) !void {
    if (self.has_xattr) {
        self._term_writer.append_to_buffer_line("@", TermWriter.Color.Green);
    } else {
        self._term_writer.append_to_buffer_line(" ", null);
    }
}

pub fn display_entry_name(self: *Self) !void {
    const c: TermWriter.Color = switch (self.entry_kind) {
        .directory => .Blue,
        else => .White,
    };
    self._term_writer.append_to_buffer_line(self.entry_name.get_slice(), c);
}

pub fn display_extra(self: *Self) void {
    switch (self.extra) {
        .None => {},
        .Sequence => |*seq| {
            self._term_writer.append_to_buffer_line(" :: ", TermWriter.Color.White);
            self._term_writer.append_to_buffer_line(seq.get_slice(), TermWriter.Color.Cyan);
        },
        .Symlink => |*symlink|{
            var color: TermWriter.Color = undefined;
            if (symlink.target_exists) {
                color = TermWriter.Color.Green;
            } else {
                color = TermWriter.Color.Red;
            }
            self._term_writer.append_to_buffer_line(" -> ", color);
            self._term_writer.append_to_buffer_line(symlink.target.get_slice(), color);
        },
    }
}

pub fn display_size(self: *Self) !void {
    switch (self.entry_kind) {
        .directory => {
            self._term_writer.append_to_buffer_line("     -", null);
        },
        else => {
            try self.size.display(&self._term_writer);
        },
    }
}

pub fn update_owner(self: *Self, other_owner: *const string.StringShortUnicode) void {
    if (!self.owner.check_is_equal(other_owner)) {
        self.owner.set_string("?");
    }
}

pub fn display(self: *Self) !void {
    const term_writer_ref = &self._term_writer;
    try self.permissions.display(term_writer_ref);
    try self.display_xtattr();
    self._term_writer.append_to_buffer_line(" ", null);
    try self.display_size();
    self._term_writer.append_to_buffer_line(" ", null);
    try self.display_owner();
    self._term_writer.append_to_buffer_line(" ", null);
    try self.date.display(term_writer_ref);
    self._term_writer.append_to_buffer_line(" ", null);
    try self.display_entry_name();
    self.display_extra();
    self._term_writer.append_to_buffer_line("\n", null);
    try self._term_writer.write_buffer();
}
