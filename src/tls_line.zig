const std = @import("std");
const Writer = std.fs.File.Writer;
const string = @import("string.zig");
const format_date = @import("format_date.zig");
const zig_utils = @import("zig_utils.zig");
const term_writer = @import("term_writer.zig");

const TermWriter = term_writer.TermWriter;

permissions: Permissions,
has_xattr: bool,
size: Size,
owner: string.StringShortUnicode,
date: Date,
filename: string.StringLongUnicode,
extra: string.StringLongUnicode,

_string_buffer: string.StringShortAscii,
_term_writer: TermWriter,

// TODO tagunion for extra: either symlink either sequence
// TODO kind? used as type for typenum?

const Date = struct {

    const DayString = string.String(2, u8);
        
    less_than_a_year_ago: u1,
    day: DayString,
    month: [3]u8,
    year_or_hour: [5]u8,
    _now: format_date.DateTime,
    _string_buffer: string.StringShortAscii,

    pub fn init() Date {
        return Date{
            .less_than_a_year_ago = 0,
            .day = DayString.init(),
            .month = [_]u8{ ' ', ' ', ' ' },
            .year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' },
            ._now = format_date.generate_datetime_from_epoch(@intCast(std.time.timestamp())),
            ._string_buffer = string.StringShortAscii.init(),
        };
    }

    pub fn reset(self: *Date) void {
        self.less_than_a_year_ago = 0;
        self.day.reset();
        self.month = [_]u8{ ' ', ' ', ' ' };
        self.year_or_hour = [_]u8{ ' ', ' ', ' ', ' ', ' ' };
    }

    pub fn deinit(self: *Date) void {
        self.less_than_a_year_ago = undefined;
        self.day.deinit();
        self.day = undefined;
        self.month = undefined;
        self.year_or_hour = undefined;
        self._now = undefined;
        self._string_buffer.deinit();
        self._string_buffer = undefined;
    }

    pub fn init_from_epoch(
        epoch: u64,
        now: format_date.DateTime,
        string_buffer: *string.StringShortAscii,
    ) Date {
        const date = format_date.generate_datetime_from_epoch(epoch);
        const is_older_by_a_year = Date._is_date_older_by_a_year(now, date);
        var ret = Date.init();

        string_buffer.reset();
        string_buffer.append_number(u8, date.day, 2, null);
        const day_slice = string_buffer.get_slice();
        // TODO: copy helper... whith len...

        ret.day.set_string(day_slice);

        const month_tmp = format_date.conv_mont_id_to_trigram(date.month);
        zig_utils.copy_arr(u8, month_tmp, &ret.month, 3);

        string_buffer.reset();
        if (is_older_by_a_year) {
            string_buffer.append_number(u16, date.year, null, null);
            string_buffer.copy_to_arr(&ret.year_or_hour, null);
        } else {
            string_buffer.append_number(u8, date.hour, null, 2);
            string_buffer.copy_to_arr(&ret.year_or_hour, null);
            ret.year_or_hour[2] = ':';
            string_buffer.reset();
            string_buffer.append_number(u8, date.minute, null, 2);
            string_buffer.copy_to_arr(&ret.year_or_hour, 3);
            string_buffer.reset();
        }
        return ret;
    }

    pub fn set_from_epoch(
        self: *Date,
        epoch: u64,
    ) void {
        const tmp = Date.init_from_epoch(epoch, self._now, &self._string_buffer);
        self.less_than_a_year_ago = tmp.less_than_a_year_ago;
        self.day = tmp.day;
        self.month = tmp.month;
        self.year_or_hour = tmp.year_or_hour;
    }

    pub fn display(self: *Date, writer: *TermWriter) !void {
        const c = TermWriter.Color.Cyan;
        try writer.write(&self.month, c);
        try writer.write(" ", null);
        try writer.write(self.day.get_slice(), c);
        try writer.write(" ", null);
        try writer.write(&self.year_or_hour, c);
    }

    fn _is_date_older_by_a_year(now: format_date.DateTime, date: format_date.DateTime) bool {
        if (date.year == now.year) {
            return false;
        } else if (date.year + 1 < now.year) {
            return true;
        } else if (date.month < now.month) {
            return false;
        } else {
            return true;
        }
    }
};

const Size = struct {
    const SizeBufferString = string.String(6, u8);

    size_indicator: u2,
    // 0: under a ko, no letter, 1: between ko an 999 To, 2: beyound
    size: f32,
    size_char: u8,
    buffer_string: SizeBufferString,

    pub fn init() Size {
        return Size{
            .size_indicator = 0,
            .size = 0,
            .size_char = 0,
            .buffer_string = SizeBufferString.init(),
        };
    }

    pub fn reset(self: *Size) void {
        self.size_indicator = 0;
        self.size = 0;
        self.size_char = 0;
        self.buffer_string.reset();
    }

    pub fn deinit(self: *Size) void {
        self.size_indicator = undefined;
        self.size = undefined;
        self.size_char = undefined;
        self.buffer_string.deinit();
        self.buffer_string = undefined;
    }

    pub fn init_from_size(number: u64) Size {
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

        return Size{
            .size_indicator = size_range,
            .size = ret,
            .size_char = c,
            .buffer_string = undefined,
        };
    }

    pub fn set_from_size(self: *Size, number: u64) void {
        const tmp = Size.init_from_size(number);
        self.size_indicator = tmp.size_indicator;
        self.size = tmp.size;
        self.size_char = tmp.size_char;
    }

    pub fn display(self: *Size, writer: *TermWriter) !void {
        const is_size_to_print = true;
        if (is_size_to_print) {
            if (self.size_indicator == 0) {
                self.buffer_string.append_number(f32, self.size, 6, null);
            } else if (self.size_indicator == 1) {
                self.buffer_string.append_number(f32, self.size, 5, null);
                self.buffer_string.append_char(self.size_char);
            } else {
                self.buffer_string.append_string("  huge");
            }
        } else {
            self.buffer_string.append_string("     -");
        }
        try writer.write(self.buffer_string.get_slice(), TermWriter.Color.Green);
    }
};

const Permissions = struct{
    permissions: [10]u8,

    pub fn init() Permissions {
        return Permissions{
            .permissions = [_]u8{' '} ** 10,
        };
    }

    pub fn reset(self: *Permissions) void {
        self.permissions = [_]u8{' '} ** 10;
    }

    pub fn deinit(self: *Permissions) void {
        self.permissions = undefined;
    }

    pub fn set_from_mode(self: *Permissions, mode: u32) void {
        // File type
        self.permissions[0] = switch (mode & 0o170000) {
            0o170000 => 'b', // Block device
            0o140000 => 'l', // Symbolic link
            0o120000 => 'n', // Socket
            0o110000 => 'p', // FIFO
            0o100000 => '-', // Directory
            0o060000 => 'b', // Block device
            0o040000 => 'd', // Regular file
            0o030000 => 'c', // Character device
            else => '-',
        };

        // Owner permissions
        self.permissions[1] = if (mode & 0o400 != 0) 'r' else '-';
        self.permissions[2] = if (mode & 0o200 != 0) 'w' else '-';
        self.permissions[3] = if (mode & 0o100 != 0) 'x' else '-';

        // Group permissions
        self.permissions[4] = if (mode & 0o040 != 0) 'r' else '-';
        self.permissions[5] = if (mode & 0o020 != 0) 'w' else '-';
        self.permissions[6] = if (mode & 0o010 != 0) 'x' else '-';

        // Others permissions
        self.permissions[7] = if (mode & 0o004 != 0) 'r' else '-';
        self.permissions[8] = if (mode & 0o002 != 0) 'w' else '-';
        self.permissions[9] = if (mode & 0o001 != 0) 'x' else '-';
    }

    pub fn display(self: *Permissions, writer: *TermWriter) !void {
        for (self.permissions) |c| {
            const r : []const u8 = &[1]u8{ c };
            const color: TermWriter.Color = switch (c) {
                'r' => .Yellow,
                'w' => .Red,
                'x' => .Green,
                'd' => .Blue,
                else => .White
            };
            _ = try writer.write(r, color); 
        }
    }
};

const Self = @This();

pub fn init() Self {
    return Self{
        .permissions = Permissions.init(),
        .has_xattr = false,
        .size = Size.init(),
        .owner = string.StringShortUnicode.init(),
        .date = Date.init(),
        .filename = string.StringLongUnicode.init(),
        .extra = string.StringLongUnicode.init(),
        ._string_buffer = string.StringShortAscii.init(),
        ._term_writer = TermWriter.init(),
    };
}

pub fn reset(self: *Self) void {
    self.permissions.reset();
    self.has_xattr = false;
    self.size.reset();
    self.owner.reset();
    self.date.reset();
    self.filename.reset();
    self._string_buffer.reset();
    self.extra.reset();
}

pub fn deinit(self: *Self) void {
    self.permissions.deinit();
    self.permissions = undefined;
    self.has_xattr = undefined;
    self.size.deinit();
    self.size = undefined;
    self.owner.deinit();
    self.owner = undefined;
    self.date.deinit();
    self.date = undefined;
    self.filename.deinit();
    self.filename = undefined;
    self._string_buffer.deinit();
    self._string_buffer = undefined;
    self._term_writer.deinit();
    self._term_writer = undefined;
    self.extra.deinit();
    self.extra = undefined;
}

pub fn display_owner(self: *Self) !void {
    try self._term_writer.write(self.owner.get_slice(), TermWriter.Color.Yellow);
}

pub fn display_xtattr(self: *Self) !void {
    if (self.has_xattr) {
    _ = try self._term_writer.write("@", TermWriter.Color.Green);
    } else {
    _ = try self._term_writer.write(" ", null);
    }
}

pub fn display_entry_name(self: *Self, writer: *Writer) !void {
    _ = try writer.write(self.filename.get_slice());
}

pub fn display(self: *Self, writer: *Writer) !void {
    const term_writer_ref = &self._term_writer;
    try self.permissions.display(term_writer_ref);
    try self.display_xtattr();
    _ = try writer.write(" ");
    try self.display_owner();
    _ = try writer.write(" ");
    try self.size.display(term_writer_ref);
    _ = try writer.write(" ");
    try self.date.display(term_writer_ref);
    _ = try writer.write(" ");
    try self.display_entry_name(writer);
    _ = try writer.write("\n");
    
}
