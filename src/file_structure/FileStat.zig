const std = @import("std");
const os = std.os;
const posix = std.posix;
const PosixStat = std.posix.Stat;
const Dir = std.fs.Dir;
const constants = @import("../constants.zig");
const string = @import("../data_structure/string.zig");
const StringExt = string.StringExt;
const StringShortUnicode = string.StringShortUnicode;

const MAX_STR_LEN_EXT = string.MAX_STR_LEN_EXT;

const Self = @This();

owner: StringShortUnicode,
mode: u32,
size: u64,
mtime: u64,
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
        username: StringShortUnicode,
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
                .username = StringShortUnicode.init(),
                .valid = false,
            };
        }
        return cache;
    }

    pub fn lookup(self: *UidCache, uid: u32) ?*const StringShortUnicode {
        for (self.entries[0..self.count]) |*entry| {
            if (entry.valid and entry.uid == uid) {
                return &entry.username;
            }
        }
        return null;
    }

    pub fn insert(self: *UidCache, uid: u32, username: StringShortUnicode) void {
        if (self.count >= MAX_CACHE_ENTRIES) return;

        self.entries[self.count] = CacheEntry{
            .uid = uid,
            .username = username,
            .valid = true,
        };
        self.count += 1;
    }
};

pub fn init(dir: *Dir, path: []const u8, uid_cache: *UidCache) !Self {
    const stat = try posix.fstatat(dir.fd, path, posix.AT.SYMLINK_NOFOLLOW);
    const mtime = stat.mtime();
    var ret = Self{
        .owner = StringShortUnicode.init(),
        .mode = stat.mode,
        .size = @bitCast(stat.size),
        .mtime = @intCast(@as(i128, mtime.sec)),
        .has_xattr = false,
        .ext = StringExt.init(),
    };

    if (uid_cache.lookup(stat.uid)) |cached_username| {
        ret.owner.append_string(cached_username.get_slice());
    } else {
        const psswd = c.getpwuid(stat.uid);
        if (psswd != null) {
            const name_c_type: [*c]u8 = psswd.*.pw_name;
            const name_z_type = std.mem.span(@as([*:0]const u8, name_c_type));
            ret.owner.append_string(name_z_type);
        } else {
            ret.owner.append_string("?");
        }
        uid_cache.insert(stat.uid, ret.owner);
    }

    if (try _has_any_extended_attributes(path)) ret.has_xattr = true;
    _fill_extension(path, &ret.ext);

    return ret;
}

fn _has_any_extended_attributes(path: []const u8) !bool {
    const c_path = std.posix.toPosixPath(path) catch return false;

    const result = c.listxattr(
        &c_path,
        null, // Don't retrieve actual attributes
        0, // Get required buffer size
        0, // options flags.
    );

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

    var uid_cache = UidCache.init();
    var cwd = std.fs.cwd();
    const stat = try Self.init(&cwd, path, &uid_cache);
    _ = stat;
}
