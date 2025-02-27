const string = @import("string.zig");

const TlsLine = struct {
    
    const Date = struct {
        less_than_a_year_ago: u1,
        day: u8,
        month: u8,
        year: u8,
        hour: u8,
        minute: u8,
    };

    const Size = struct {
        size_indicator: u2, // u2: 0: under a ko, no letter, 1: between ko an 999 To, 2: beyound
        size: f32,
        size_char: u8,
    };

    permission: [10]u8,
    has_x_attr: u1,
    size: Size,
    owner: string.StringShortUnicode,
    date: Date,
    filename: string.StringLongUnicode,

    // TODO tagunion for extra: either symlink either sequence
    // TODO kind? used as type for typenum?
    
    const Self = @This();

    pub fn init() Self {
        return Self{
            .permission = [_]u8{' '} ** 10,
            .has_x_attr = 0,
            .size = 0,
            .owner = string.StringShortUnicode.init(),
            .date = Date {
                .less_than_a_year_ago = undefined,
                .day = undefined,
                .month = undefined,
                .year = undefined,
                .hour: = undefined,
                .minute = undefined,
            },
            .filename = string.StringLongUnicode.init(),
        };
    }

};
