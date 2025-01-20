const std = @import("std");

// The floor is malloc.
pub fn StringOnStack(comptime max_len: usize) type {
    return struct {
        array: [max_len]u8,
        str_len: usize,
        _append_number_buffer: [8]u8,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .array = [_]u8{' '} ** max_len,
                .str_len = 0,
                ._append_number_buffer = undefined,
            };
        }

        pub fn reset(self: *Self) void {
            self.str_len = 0;
        }

        pub fn deinit(self: *Self) void {
            var i: usize = 0;
            while (i < self.array.len) : (i += 1) {
                self.array[i] = ' ';
            }
            self.str_len = 0;
            self.array = undefined;
        }

        pub fn append_char(self: *Self, char: u8) void {
            if (self.str_len == self.array.len) return;
            self.array[self.str_len] = char;
            self.str_len += 1;
        }

        pub fn append_string(self: *Self, str: []const u8) void {
            var i: usize = 0;
            var max_i: usize = 0;

            if ((self.str_len + str.len) > self.array.len) {
                max_i = self.array.len - self.str_len;
            } else {
                max_i = str.len;
            }
            while (i < max_i) : (i += 1) {
                self.array[self.str_len + i] = str[i];
            }
            self.str_len += i;
        }

        pub fn append_number(self: *Self, comptime T: type, number: T) !void {
            const num_as_string_tmp = try std.fmt.bufPrint(
                &self._append_number_buffer,
                "{}",
                .{number},
            );
            self.append_string(num_as_string_tmp);
            self._append_number_buffer = undefined;
        }
        pub fn print_debug(self: *Self) void {
            std.debug.print("{s}\n", .{self.array[0..self.str_len]});
        }

        pub fn trim_str(self: *Self, trim_range: usize) void {
            self.str_len -= @min(trim_range, self.str_len);
        }

        pub fn get_slice(self: *Self) []const u8 {
            return self.array[0..self.str_len];
        }
    };
}

test "append_str" {
    var str1 = StringOnStack(10).init();
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
    var str1 = StringOnStack(10).init();
    try str1.append_number(u16, 45);
    try std.testing.expectEqualSlices(u8, "45", str1.get_slice());
    try str1.append_number(u8, 12);
    try std.testing.expectEqualSlices(u8, "4512", str1.get_slice());
    str1.deinit();
}
