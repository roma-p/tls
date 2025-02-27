const std = @import("std");
const constants = @import("constants.zig");

// not yet unicode...
pub const StringLongUnicode = String(constants.MAX_STR_LEN_ENTRY, u8);
pub const StringShortUnicode = String(constants.MAX_STR_LEN_OWNER, u8);

pub fn String(comptime max_len: usize, comptime string_type: type) type {
    return struct {
        _array: [max_len]string_type,
        _str_len: usize,
        _append_number_buffer: [16]string_type,

        const Self = @This();

        pub fn init() Self {
            return Self{
                ._array = [_]string_type{' '} ** max_len,
                ._str_len = 0,
                ._append_number_buffer = undefined,
            };
        }

        pub fn reset(self: *Self) void {
            self._str_len = 0;
        }

        pub fn deinit(self: *Self) void {
            var i: usize = 0;
            while (i < self._array.len) : (i += 1) {
                self._array[i] = ' ';
            }
            self._str_len = 0;
            self._array = undefined;
        }

        pub fn append_char(self: *Self, char: string_type) void {
            if (self._str_len == self._array.len) return;
            self._array[self._str_len] = char;
            self._str_len += 1;
        }

        pub fn append_string(self: *Self, str: []const string_type) void {
            var i: usize = 0;
            var max_i: usize = 0;

            if ((self._str_len + str.len) > self._array.len) {
                max_i = self._array.len - self._str_len;
            } else {
                max_i = str.len;
            }
            while (i < max_i) : (i += 1) {
                self._array[self._str_len + i] = str[i];
            }
            self._str_len += i;
        }

        pub fn append_number(
            self: *Self,
            comptime T: type,
            number: T,
            left_margin: ?usize,
            comptime zero_padding: ?usize,
        ) void {
            const zp = if (zero_padding == null) "0" else _conv_zero_padd_to_str(zero_padding.?);

            var num_as_string_tmp: []const string_type = undefined;
            const num_as_string_err: []const string_type = "??";
            if (@mod(number, 1) == 0) {
                num_as_string_tmp = std.fmt.bufPrint(
                    &self._append_number_buffer,
                    "{d:0>" ++ zp ++ ".0}",
                    .{number},
                ) catch num_as_string_err;
            } else {
                num_as_string_tmp = std.fmt.bufPrint(
                    &self._append_number_buffer,
                    "{d:0>" ++ zp ++ ".1}",
                    .{number},
                ) catch num_as_string_err;
            }

            if (left_margin != null and num_as_string_tmp.len < left_margin.?) {
                var i: usize = 0;
                const max: usize = left_margin.? - num_as_string_tmp.len;
                while (i < max) : (i += 1) {
                    self.append_char(' ');
                }
                self.append_string(num_as_string_tmp);
            } else {
                self.append_string(num_as_string_tmp);
            }
            self._append_number_buffer = undefined;
        }

        pub fn print_debug(self: *Self) void {
            std.debug.print("{s}\n", .{self._array[0..self._str_len]});
        }

        pub fn trim_str(self: *Self, trim_range: usize) void {
            self._str_len -= @min(trim_range, self._str_len);
        }

        pub fn get_slice(self: *const Self) []const string_type {
            return self._array[0..self._str_len];
        }

        inline fn _conv_zero_padd_to_str(comptime zero_padding: usize) *const [1:0]u8 {
            // TODO: better comppilation time method to do this?
            return switch (zero_padding) {
                0 => "0",
                1 => "1",
                2 => "2",
                3 => "3",
                4 => "4",
                5 => "5",
                6 => "6",
                7 => "7",
                8 => "8",
                9 => "9",
                else => "9",
            };
        }
    };
}

test "append_str" {
    var str1 = String(10, u8).init();
    str1.append_string("1234");
    try std.testing.expectEqualSlices(u8, "1234", str1.get_slice());
    str1.append_string("5678");
    try std.testing.expectEqualSlices(u8, "12345678", str1.get_slice());
    str1.reset();
    str1.append_string("1234");
    try std.testing.expectEqualSlices(u8, "1234", str1.get_slice());
    str1.deinit();
}

test "append_number" {
    var str1 = String(10, u8).init();
    str1.append_number(u16, 45, null, null);
    try std.testing.expectEqualSlices(u8, "45", str1.get_slice());
    str1.append_number(u8, 12, null, null);
    try std.testing.expectEqualSlices(u8, "4512", str1.get_slice());
    str1.deinit();
    var str2 = String(10, u8).init();
    str2.append_number(u16, 45, 4, null);
    try std.testing.expectEqualSlices(u8, "  45", str2.get_slice());
    str2.deinit();
    var str3 = String(10, u8).init();
    str3.append_number(u16, 45, 1, 0);
    try std.testing.expectEqualSlices(u8, "45", str3.get_slice());
    str3.deinit();
    var str4 = String(10, u8).init();
    str4.append_number(u16, 4, null, 2);
    try std.testing.expectEqualSlices(u8, "04", str4.get_slice());
    str4.deinit();
}
