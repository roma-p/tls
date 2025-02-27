const std = @import("std");
const constants = @import("constants.zig");
const os = std.os;
const posix = std.posix;
const PosixStat = std.posix.Stat;
const Dir = std.fs.Dir;

const c = @cImport({
    @cInclude("sys/xattr.h");
    @cInclude("pwd.h");
});

const StatRefined = struct {
    owner: [constants.MAX_STR_LEN_OWNER]u8,
    owner_len: usize,
    mode: u32,
    size: u64,
    mtime: u64,
};

// TODO: term entry?

pub fn posix_stat(dir: Dir, path: []const u8) !StatRefined {
    const stat = try posix.fstatat(dir.fd, path, 0);
    const psswd = c.getpwuid(stat.uid);
    const name_c_type: [*c]u8 = psswd.*.pw_name;
    const name_z_type = std.mem.span(@as([*:0]const u8, name_c_type));
    // considering that the C string is null terminated.
    const mtime = stat.mtime();
    var ret = StatRefined{
        .owner = [_]u8{0} ** constants.MAX_STR_LEN_OWNER,
        .owner_len = name_z_type.len,
        .mode = stat.mode,
        .size = @bitCast(stat.size),
        .mtime = @intCast(@as(i128, mtime.tv_sec)),
    };

    var i: usize = 0;
    while (i < constants.MAX_STR_LEN_OWNER) : (i += 1) {
        if (name_z_type[i] == 0) break;
        if (i == constants.MAX_STR_LEN_OWNER) break;
        ret.owner[i] = name_z_type[i];
    }
    return ret;
}

pub fn hasAnyExtendedAttributes(path: []const u8) !bool {
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

    const stat = try posix_stat(std.fs.cwd(), path);
    _ = stat;
}
