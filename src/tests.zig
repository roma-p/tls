comptime {
    // Tls pulls in the whole tree (data structures, file_structure, sequence,
    // tls_line, DateTime, TermWriter), so every test block gets analyzed.
    _ = @import("Tls.zig");
}
