const std = @import("std");

pub fn Array(comptime max_len: usize, comptime T: type, default: T) type {
    return struct {
        array: [max_len]T,
        len: usize,
        default: T,
        max_len: usize,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .array = [_]T{default} ** max_len,
                .len = 0,
                .default = default,
                .max_len = max_len,
            };
        }

        pub fn reset(self: *Self) void {
            self.len = 0;
        }

        pub fn set_to_default(self: *Self) void {
            self.array = [_]T{default} ** max_len;
        }

        pub fn deinit(self: *Self) void {
            self.array = undefined;
            self.len = 0;
            self.max_len = 0;
        }

        pub fn append(self: *Self, elem: T) bool {
            if (self.len >= self.array.len) return false;
            self.array[self.len] = elem;
            self.len += 1;
            return true;
        }

        pub fn extend(self: *Self, slice: []const T) bool {
            var i: usize = 0;
            var max_i: usize = 0;
            var ret: bool = undefined;

            if ((self.len + slice.len) > self.array.len) {
                ret = false;
                if (self.array.len > self.len) {
                    max_i = self.array.len - self.len;
                } else {
                    return false;
                }
            } else {
                ret = true;
                max_i = slice.len;
            }
            while (i < max_i) : (i += 1) {
                self.array[self.len + i] = slice[i];
            }
            self.len += i;
            return ret;
        }

        pub fn get_last(self: *Self) T {
            return self.array[self.len - 1];
        }

        pub fn get_at_unsafe(self: *Self, i: usize) T {
            return self.array[i];
        }

        pub fn set(self: *Self, slice: []const T) bool {
            self.reset();
            return self.extend(slice);
        }

        pub fn trim(self: *Self, trim_range: usize) void {
            self.len -= @min(trim_range, self.len);
        }

        pub fn get_slice(self: *const Self) []const T {
            return self.array[0..self.len];
        }

        pub fn copy_to_arr(self: *Self, dst: []T, dst_shift: ?usize) void {
            const i_dst_shift: usize = if (dst_shift != null) dst_shift.? else 0;

            const i_end = @min(self.len, dst.len - i_dst_shift);
            var i: usize = 0;

            while (i < i_end) : (i += 1) {
                dst[i + i_dst_shift] = self.array[i];
            }
        }

        pub fn check_is_equal(self: *Self, other: *const Self) bool {
            if (self.len != other.len) return false;
            for (self.array, 0..) |elem, i| {
                if (elem != other.array[i])
                    return false;
            }
            return true;
        }

        pub fn print_debug(self: *const Self) void {
            std.debug.print("{any}\n", .{self.array[0..self.len]});
        }
    };
}
