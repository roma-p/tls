fn format_size(number: u16) struct { f16, u8 } {
    const ko = 1_000;
    const mo = 1_000_000;
    const go = 1_000_000_000;
    const to = 1_000_000_000_000;

    if (number > to) {
        return .{ number / to, 'T' };
    } else if (number > go) {
        return .{ number / go, 'G' };
    } else if (number > mo) {
        return .{ number / mo, 'M' };
    } else if (number > ko) {
        return .{ number / ko, 'k' };
    } else return .{ number / ko, ' ' };
}
