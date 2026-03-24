const std = @import("std");
const Array = @import("array.zig").Array;

pub const MAX_STR_LEN_ENTRY = 256;
pub const MAX_STR_LEN_OWNER = 50;
pub const MAX_STR_LEN_EXT = 16;

pub const StringExt = String(MAX_STR_LEN_EXT, u8);
pub const StringLong = String(MAX_STR_LEN_ENTRY, u8);
pub const StringShort = String(MAX_STR_LEN_OWNER, u8);

pub fn String(comptime max_len: usize, comptime string_type: type) type {
    return struct {
        _array: Array(max_len, string_type, ' '),
        _append_number_buffer: [16]string_type,

        const Self = @This();

        pub fn init() Self {
            return Self{
                ._array = Array(max_len, string_type, ' ').init(),
                ._append_number_buffer = undefined,
            };
        }

        pub fn init_from_slice(slice: []const string_type) Self {
            var tmp = Self.init();
            tmp.set_string(slice);
            return tmp;
        }

        pub fn reset(self: *Self) void {
            self._array.reset();
        }

        pub fn deinit(self: *Self) void {
            self.* = undefined;
        }

        pub fn get_len(self: *Self) usize {
            return self._array.len;
        }

        pub fn get_max_len(self: *Self) usize {
            return self._array.max_len;
        }

        pub fn append_char(self: *Self, char: string_type) void {
            _ = self._array.append(char);
        }

        pub fn append_string(self: *Self, str: []const string_type) void {
            _ = self._array.extend(str);
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

        pub fn set_string(self: *Self, str: []const string_type) void {
            _ = self._array.set(str);
        }
        
        pub fn is_not_null(self: *Self) bool { return self.get_len() != 0; }

        pub fn check_is_equal(self: *Self, other: *const Self) bool {
            // const tmp = other._array;
            return self._array.check_is_equal(&other._array);
        }

        pub fn print_debug(self: *const Self) void {
            std.debug.print("{s}\n", .{self._array.array[0..self._array.len]});
        }

        pub fn trim_str(self: *Self, trim_range: usize) void {
            self._array.trim(trim_range);
        }

        pub fn get_slice(self: *const Self) []const string_type {
            return self._array.get_slice();
        }

        pub fn copy_to_arr(self: *Self, dst: []string_type, dst_shift: ?usize) void {
            self._array.copy_to_arr(dst, dst_shift);
        }

        inline fn _conv_zero_padd_to_str(comptime zero_padding: usize) *const [1:0]u8 {
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
