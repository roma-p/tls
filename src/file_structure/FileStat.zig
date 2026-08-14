const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const posix = std.posix;
const PosixStat = std.posix.Stat;
const Dir = std.fs.Dir;
const constants = @import("../constants.zig");
const string = @import("../data_structure/string.zig");
const StringExt = string.StringExt;
const StringShort = string.StringShort;

const MAX_STR_LEN_EXT = string.MAX_STR_LEN_EXT;

const Self = @This();

uid: u32,
mode: u32,
size: u64,
mtime: i64,
has_xattr: bool,
ext: StringExt,

const c = @cImport({
    @cInclude("sys/xattr.h");
    @cInclude("pwd.h");
});

pub const UidCache = struct {
    const MAX_CACHE_ENTRIES = 32;

    const CacheEntry = struct {
        uid: u32,
        username: StringShort,
        valid: bool,
    };

    entries: [MAX_CACHE_ENTRIES]CacheEntry,
    count: usize,

    pub fn init() UidCache {
        var cache = UidCache{
            .entries = undefined,
            .count = 0,
        };
        for (&cache.entries) |*entry| {
            entry.* = CacheEntry{
                .uid = 0,
                .username = StringShort.init(),
                .valid = false,
            };
        }
        return cache;
    }

    pub fn lookup(self: *UidCache, uid: u32) ?*const StringShort {
        for (self.entries[0..self.count]) |*entry| {
            if (entry.valid and entry.uid == uid) {
                return &entry.username;
            }
        }
        return null;
    }

    pub fn insert(self: *UidCache, uid: u32, username: StringShort) void {
        if (self.count >= MAX_CACHE_ENTRIES) return;

        self.entries[self.count] = CacheEntry{
            .uid = uid,
            .username = username,
            .valid = true,
        };
        self.count += 1;
    }

    pub fn get_or_resolve(self: *UidCache, uid: u32) []const u8 {
        if (self.lookup(uid)) |cached| return cached.get_slice();

        var username = StringShort.init();
        const psswd = c.getpwuid(uid);
        if (psswd != null) {
            const name_c_type: [*c]u8 = psswd.*.pw_name;
            username.append_string(std.mem.span(@as([*:0]const u8, name_c_type)));
        } else {
            username.append_string("?");
        }
        self.insert(uid, username);
        if (self.lookup(uid)) |cached| return cached.get_slice();
        return "?";
    }
};

pub fn init(dir: *Dir, path: []const u8) !Self {
    const stat = try posix.fstatat(dir.fd, path, posix.AT.SYMLINK_NOFOLLOW);
    const mtime = stat.mtime();
    var ret = Self{
        .uid = stat.uid,
        .mode = stat.mode,
        .size = @bitCast(stat.size),
        .mtime = @intCast(mtime.sec),
        .has_xattr = false,
        .ext = StringExt.init(),
    };

    if (_has_any_extended_attributes(dir, path)) ret.has_xattr = true;
    _fill_extension(path, &ret.ext);

    return ret;
}

fn _has_any_extended_attributes(dir: *Dir, path: []const u8) bool {
    const fd = posix.openat(
        dir.fd,
        path,
        .{ .NOFOLLOW = true, .NONBLOCK = true },
        0,
    ) catch return false;
    defer posix.close(fd);

    const result = switch (builtin.os.tag) {
        .macos => c.flistxattr(fd, null, 0, 0),
        .linux => c.flistxattr(fd, null, 0),
        else => return false,
    };

    return result > 0;
}

fn _fill_extension(filename: []const u8, extString: *StringExt) void {
    var i: usize = 1;
    var j: usize = 0;
    var dot_found: bool = false;
    while (i < MAX_STR_LEN_EXT) : ( i +=1 ) {
        if (i >= filename.len) break;
        j = filename.len - i;
        if (filename[j] == '.') {
            dot_found = true;
            break;
        } 
    }
    if (dot_found) {
        extString.reset();
        for (filename[j+1..]) |ch| {
            extString.append_char(std.ascii.toLower(ch));
        }
    } else {
        extString.reset();
    }
}

test "file info" {
    const path = "./test.txt";

    // Create test file
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var cwd = std.fs.cwd();
    const stat = try Self.init(&cwd, path);
    _ = stat;
}
