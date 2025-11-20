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
            const max_i: usize = blk: {
                if ((self.len + slice.len) > self.array.len) {
                    if (self.array.len > self.len) {
                        break :blk self.array.len - self.len;
                    } else {
                        return false;
                    }
                } else {
                    break :blk slice.len;
                }
            };

            // Use bulk memory copy instead of element-by-element
            @memcpy(self.array[self.len..][0..max_i], slice[0..max_i]);
            self.len += max_i;

            return max_i == slice.len;
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

            // Use bulk memory copy instead of element-by-element
            @memcpy(dst[i_dst_shift..][0..i_end], self.array[0..i_end]);
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
