pub fn format_size(number: u64) struct { f32, u8, u2 } {
    // u2: 0: under a ko, no letter, 1: between ko an 999 To, 2: beyound

    const ko = 1_000;
    const mo = 1_000_000;
    const go = 1_000_000_000;
    const to = 1_000_000_000_000;

    const tmp_1: i128 = number;
    const tmp_2: f64 = @floatFromInt(tmp_1);

    var c: u8 = ' ';
    var tmp_3: f64 = 0;
    var size_range: u2 = 1;

    if (tmp_2 > 999 * to) {
        c = ' ';
        size_range = 2;
    } else if (tmp_2 > to) {
        c = 'T';
        tmp_3 = tmp_2 / to;
    } else if (tmp_2 > go) {
        c = 'G';
        tmp_3 = tmp_2 / go;
    } else if (tmp_2 > mo) {
        c = 'M';
        tmp_3 = tmp_2 / mo;
    } else if (tmp_2 > ko) {
        c = 'k';
        tmp_3 = tmp_2 / ko;
    } else {
        c = ' ';
        size_range = 0;
        tmp_3 = tmp_2;
    }
    var ret: f32 = @floatCast(tmp_3);
    ret = @round(ret * 10) / 10;
    return .{ ret, c, size_range };
}
