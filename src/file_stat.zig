const std = @import("std");
const constants = @import("constants.zig");
const os = std.os;
const posix = std.posix;
const PosixStat = std.posix.Stat;
const Dir = std.fs.Dir;

const c = @cImport({
    @cInclude("pwd.h");
});

const StatRefined = struct {
    owner: [constants.MAX_STR_LEN_OWNER]u8,
    owner_len: usize,
    mode: u32,
    // mtime: u32,
};

pub fn posix_stat(dir: Dir, path: []const u8) !StatRefined {
    const stat = try posix.fstatat(dir.fd, path, 0);
    const psswd = c.getpwuid(stat.uid);
    const name_c_type: [*c]u8 = psswd.*.pw_name;
    const name_z_type = std.mem.span(@as([*:0]const u8, name_c_type));
    // considering that the C string is null terminated.
    var ret = StatRefined{
        .owner = [_]u8{0} ** constants.MAX_STR_LEN_OWNER,
        .owner_len = name_z_type.len,
        .mode = stat.mode,
    };

    var i: usize = 0;
    while (i < constants.MAX_STR_LEN_OWNER) : (i += 1) {
        if (name_z_type[i] == 0) break;
        if (i == constants.MAX_STR_LEN_OWNER) break;
        ret.owner[i] = name_z_type[i];
    }
    return ret;
}

test "file info" {
    const path = "./test.txt";

    // Create test file
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const stat = try posix_stat(std.fs.cwd(), path);
    std.debug.print("\n {s} \n", .{stat.owner[0..stat.owner_len]});
}
