const std = @import("std");
const Tls = @import("Tls.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tls = try Tls.init(allocator);
    defer tls.deinit();
    if (std.os.argv.len == 1) {
        try tls.process(".");
    } else {
        const l: []const u8 = std.mem.span(std.os.argv[1]);
        try tls.process(l);
    }
}
