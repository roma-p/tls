const std = @import("std");
const string = @import("../data_structure/string.zig");
const Array = @import("../data_structure/array.zig").Array;
const FileStat = @import("FileStat.zig");

const fs = std.fs;
const Dir = fs.Dir;
const FileKind = fs.File.Kind;
const StringLongUnicode = string.StringLongUnicode;

const Self = @This();

pub const MAX_FILE_IN_DIR = 1024;

dir_entry_array: DirEntryArray,
file_stat_array: FileStatArray,
max_owner_len: usize,

pub const DirEntry = struct {
    name: StringLongUnicode,
    kind: FileKind,
};

const default_dir_entry = DirEntry{
    .name = StringLongUnicode.init(),
    .kind = .file,
};

const DirEntryArray = Array(
    MAX_FILE_IN_DIR,
    DirEntry,
    default_dir_entry,
);

const FileStatArray = Array(MAX_FILE_IN_DIR, FileStat, undefined);

pub fn init() Self {
    return Self{
        .dir_entry_array = DirEntryArray.init(),
        .file_stat_array = FileStatArray.init(),
        .max_owner_len = 0,
    };
}

pub fn reset(self: *Self) void {
    self.dir_entry_array.set_to_default();
    self.dir_entry_array.reset();
    self.file_stat_array.set_to_default();
    self.file_stat_array.reset();
    self.max_owner_len = 0;
}

pub fn deinit(self: *Self) void {
    self.dir_entry_array.deinit();
    self.file_stat_array.deinit();
    self.max_owner_len = 0;
}

pub fn append(self: *Self, dir_entry: DirEntry) bool {
    return self.dir_entry_array.append(dir_entry);
}

pub fn populate(self: *Self, dir: *Dir, eval_file_stat: bool) !void {
    self.reset();

    var walker = dir.iterate();
    var i: usize = 0;

    while (try walker.next()) |entry| {
        if (i >= MAX_FILE_IN_DIR) break; // overflow.
        self.dir_entry_array.array[i].kind = entry.kind;
        self.dir_entry_array.array[i].name.append_string(entry.name);
        i += 1;
    }
    std.mem.sort(DirEntry, &self.dir_entry_array.array, {}, _less_than);
    self.dir_entry_array.len = i;

    walker = undefined;

    if (!eval_file_stat) return;

    for (self.dir_entry_array.get_slice()) |c| {
        const file_stat = try FileStat.init(dir, c.name.get_slice());
        _ = self.file_stat_array.append(file_stat);
        const owner_len = file_stat.owner._array.len;
        if (owner_len > self.max_owner_len) {
            self.max_owner_len = owner_len;
        }
    }
}

pub fn get_slice(self: *Self) []const DirEntry {
    return self.dir_entry_array.get_slice();
}

pub fn print_debug(self: *Self) void {
    std.debug.print("dir content\n", .{});
    const slice = self.get_slice();
    for (slice) |entry| {
        std.debug.print("{s}\n", .{entry.name.get_slice()});
    }
}

fn _less_than(_: void, lhs: DirEntry, rhs: DirEntry) bool {
    const lhs_slice = lhs.name.get_slice();
    const rhs_slice = rhs.name.get_slice();
    if (std.mem.eql(u8, lhs_slice, "")) {
        return false; // probably the opposite?
    } else if (std.mem.eql(u8, rhs_slice, "")) {
        return true;
    } else {
        return std.ascii.orderIgnoreCase(lhs_slice, rhs_slice) == .lt;
    }
}
