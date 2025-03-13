const Tls = @import("Tls.zig");

pub fn main() !void {
    var tls = Tls.init();
    defer tls.deinit();
    try tls.process();
}
