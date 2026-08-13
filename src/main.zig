const std = @import("std");
const Tls = @import("Tls.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tls = try Tls.init(allocator);
    defer tls.deinit();
    const path: []const u8 = if (std.os.argv.len > 1)
        std.mem.span(std.os.argv[1])
    else
        ".";
    tls.process(path) catch |err| {
        const reason = switch (err) {
            error.FileNotFound => "no such file or directory",
            error.NotDir => "not a directory",
            error.AccessDenied => "permission denied",
            else => @errorName(err),
        };
        std.debug.print("tls: cannot access '{s}': {s}\n", .{ path, reason });
        std.process.exit(1);
    };
}
