const std = @import("std");
const os = std.os;
const posix = std.posix;
const PosixStat = std.posix.Stat;
const Dir = std.fs.Dir;
const constants = @import("../constants.zig");
const StringShortUnicode = @import("../data_structure/string.zig").StringShortUnicode;

const Self = @This();

owner: StringShortUnicode,
mode: u32,
size: u64,
mtime: u64,
has_xattr: bool,

const c = @cImport({
    @cInclude("sys/xattr.h");
    @cInclude("pwd.h");
});

pub fn init(dir: *Dir, path: []const u8) !Self {
    const stat = try posix.fstatat(dir.fd, path, 0); // TODO: return "unknown stat..."
    const psswd = c.getpwuid(stat.uid);
    const name_c_type: [*c]u8 = psswd.*.pw_name;
    const name_z_type = std.mem.span(@as([*:0]const u8, name_c_type));
    const mtime = stat.mtime();
    var ret = Self{
        .owner = StringShortUnicode.init(),
        .mode = stat.mode,
        .size = @bitCast(stat.size),
        .mtime = @intCast(@as(i128, mtime.sec)),
        .has_xattr = false,
    };

    // considering that the C string is null terminated.
    var i: usize = 0;
    while (i < constants.MAX_STR_LEN_OWNER) : (i += 1) {
        if (name_z_type[i] == 0) break;
        if (i == constants.MAX_STR_LEN_OWNER) break;
        ret.owner.append_char(name_z_type[i]);
    }

    if (try _has_any_extended_attributes(path)) ret.has_xattr = true;

    return ret;
}

pub fn _has_any_extended_attributes(path: []const u8) !bool {
    const result = c.listxattr(
        path.ptr,
        null, // Don't retrieve actual attributes
        0, // Get required buffer size
        0, // options flags.
    );

    if (result > 0) {
        return true;
    } else if (result == 0) {
        return false;
    } else return false; // FIXE ME: masking errors...(if -1)

}

test "file info" {
    const path = "./test.txt";

    // Create test file
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const stat = try Self.init(std.fs.cwd(), path);
    _ = stat;
}
