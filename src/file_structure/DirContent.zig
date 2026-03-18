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
    const a = lhs.name.get_slice();
    const b = rhs.name.get_slice();

    // Sort by extension first so same-extension files are adjacent (enables sequence grouping)
    const ext_a = _get_extension(a);
    const ext_b = _get_extension(b);
    const ext_ord = _natural_order(ext_a, ext_b);
    if (ext_ord != .eq) return ext_ord == .lt;

    // Same extension: natural sort by full name
    return _natural_order(a, b) == .lt;
}

fn _get_extension(name: []const u8) []const u8 {
    var i: usize = name.len;
    while (i > 0) {
        i -= 1;
        if (name[i] == '.') return name[i..];
    }
    return "";
}

fn _natural_order(a: []const u8, b: []const u8) std.math.Order {
    var i: usize = 0;
    var j: usize = 0;
    while (i < a.len and j < b.len) {
        const a_is_digit = std.ascii.isDigit(a[i]);
        const b_is_digit = std.ascii.isDigit(b[j]);

        if (a_is_digit and b_is_digit) {
            var a_num: u64 = 0;
            var a_start = i;
            while (a_start < a.len and std.ascii.isDigit(a[a_start])) : (a_start += 1) {
                a_num = a_num * 10 + (a[a_start] - '0');
            }
            var b_num: u64 = 0;
            var b_start = j;
            while (b_start < b.len and std.ascii.isDigit(b[b_start])) : (b_start += 1) {
                b_num = b_num * 10 + (b[b_start] - '0');
            }
            if (a_num != b_num) return std.math.order(a_num, b_num);
            i = a_start;
            j = b_start;
        } else {
            const ac = std.ascii.toLower(a[i]);
            const bc = std.ascii.toLower(b[j]);
            if (ac != bc) return std.math.order(ac, bc);
            i += 1;
            j += 1;
        }
    }
    return std.math.order(a.len, b.len);
}
