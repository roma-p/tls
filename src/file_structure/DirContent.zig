const std = @import("std");
const string = @import("../data_structure/string.zig");
const Array = @import("../data_structure/array.zig").Array;
const DynamicArray = @import("../data_structure/darray.zig").DynamicArray;
const FileStat = @import("FileStat.zig");

const fs = std.fs;
const Dir = fs.Dir;
const FileKind = fs.File.Kind;
const StringLongUnicode = string.StringLongUnicode;

const Self = @This();

pub const FILE_IN_DIR_INIT_SIZE = 64;

dir_entry_array: DirEntryArray,
file_stat_array: FileStatArray,
max_owner_len: usize,
allocator: std.mem.Allocator,

pub const DirEntry = struct {
    name: StringLongUnicode,
    kind: FileKind,
};

const default_dir_entry = DirEntry{
    .name = StringLongUnicode.init(),
    .kind = .file,
};

const DirEntryArray = DynamicArray(
    FILE_IN_DIR_INIT_SIZE,
    DirEntry,
    default_dir_entry,
);

const FileStatArray = DynamicArray(
    FILE_IN_DIR_INIT_SIZE,
    FileStat,
    undefined
);

pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .allocator = allocator,
        .dir_entry_array = try DirEntryArray.init(allocator),
        .file_stat_array = try FileStatArray.init(allocator),
        .max_owner_len = 0,
    };
}

pub fn reset(self: *Self) void {
    self.dir_entry_array.reset();
    self.file_stat_array.reset();
    self.max_owner_len = 0;
}

pub fn deinit(self: *Self) void {
    self.dir_entry_array.deinit();
    self.file_stat_array.deinit();
    self.* = undefined;
}

pub fn append(self: *Self, dir_entry: DirEntry) bool {
    return self.dir_entry_array.append(dir_entry);
}

pub fn populate(self: *Self, dir: *Dir, eval_file_stat: bool) !void {
    self.reset();

    var walker = dir.iterate();
    var i: usize = 0;

    while (try walker.next()) |entry| {
        try self.dir_entry_array.ensureCapacity(i + 1);
        self.dir_entry_array.array[i].kind = entry.kind;
        self.dir_entry_array.array[i].name.reset();
        self.dir_entry_array.array[i].name.append_string(entry.name);
        i += 1;
        self.dir_entry_array.len = i;
    }
    // Only sort the populated entries, not the entire array
    std.mem.sort(DirEntry, self.dir_entry_array.array[0..i], {}, _less_than);

    walker = undefined;

    if (!eval_file_stat) return;

    // Create UID cache to avoid repeated getpwuid() calls
    var uid_cache = FileStat.UidCache.init();

    var j: usize = 0;
    for (self.dir_entry_array.array[0..i]) |c| {
        const file_stat = FileStat.init(dir, c.name.get_slice(), &uid_cache) catch {
            continue;
        };
        self.dir_entry_array.array[j] = c;
        try self.file_stat_array.append(file_stat);
        const owner_len = file_stat.owner._array.len;
        if (owner_len > self.max_owner_len) {
            self.max_owner_len = owner_len;
        }
        j += 1;
    }
    self.dir_entry_array.len = j;
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
    // No need for empty string checks since we only sort populated entries
    return std.ascii.orderIgnoreCase(lhs_slice, rhs_slice) == .lt;
}
