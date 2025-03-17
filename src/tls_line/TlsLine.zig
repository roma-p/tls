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

pub fn init() Self {
    return Self{
        .permissions = SectionPermissions.init(),
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

pub fn update_owner(self: *Self, other_owner: *const string.StringShortUnicode) void {
    if (! self.owner.check_is_equal(other_owner)) {
        self.owner.set_string("?");
    }
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
