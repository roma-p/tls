const std = @import("std");
const constants = @import("constants.zig");
const string = @import("string.zig");

const fs = std.fs;
const Dir = fs.Dir;
const FileKind = fs.File.Kind;
const StringLongUnicode = string.StringLongUnicode;

const _array = @import("array.zig");
const Array = _array.Array;

// CustomDirEntry with StackOnStrings. name dooes not belong to me, only memory view.

pub const DirContent = struct {
    pub const DirEntry = struct {
        name: StringLongUnicode,
        kind: FileKind,
    };

    const default_dir_entry = DirEntry{
        .name = StringLongUnicode.init(),
        .kind = .file,
    };

    const DirEntryArray = Array(
        constants.MAX_FILE_IN_DIR,
        DirEntry,
        default_dir_entry,
    );

    const Self = @This();

    dir_entry_array: DirEntryArray,

    pub fn init() Self {
        return Self{
            .dir_entry_array = DirEntryArray.init(),
        };
    }

    pub fn reset(self: *Self) void {
        self.dir_entry_array.array = [_]DirEntry{default_dir_entry} ** constants.MAX_FILE_IN_DIR;
        self.dir_entry_array.reset();
    }

    pub fn deinit(self: *Self) void {
        self.dir_entry_array.deinit();
    }

    pub fn populate(self: *Self, dir: *const Dir) !void {
        self.reset();

        var walker = dir.iterate();
        var i: usize = 0;

        while (try walker.next()) |entry| {
            if (i >= constants.MAX_FILE_IN_DIR) break; // overflow.
            self.dir_entry_array.array[i].kind = entry.kind;
            self.dir_entry_array.array[i].name.append_string(entry.name);
            i += 1;
        }
        std.mem.sort(DirEntry, &self.dir_entry_array.array, {}, _less_than);
        self.dir_entry_array.len = i;

        walker = undefined;
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
};

fn _less_than(_: void, lhs: DirContent.DirEntry, rhs: DirContent.DirEntry) bool {
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
