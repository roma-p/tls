
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DynamicArray(comptime init_size: usize, comptime T: type, default: T) type {
    return struct {
        len: usize,
        capacity: usize,
        default: T,
        array: []T,
        allocator: Allocator,

        const Self = @This();


        pub fn init(allocator: Allocator) !Self {
            const ret = Self{
                .len = 0,
                .capacity = init_size,
                .default = default,
                .array = try allocator.alloc(T, init_size),
                .allocator = allocator,
            };
            @memset(ret.array[0..ret.capacity], ret.default);
            return ret;
        }

        pub fn reset(self: *Self) void {
            self.len = 0;
        }

        pub fn set_to_default(self: *Self) void {
            @memset(self.array[0..self.capacity], self.default);
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.array);
            self.* = undefined;
        }

        pub fn append(self: *Self, elem: T) !void{
            try self.ensureCapacity(self.len + 1);
            self.array[self.len] = elem;
            self.len += 1;
        }

        pub fn extend(self: *Self, slice: []const T) !void {
            try self.ensureCapacity(self.len + slice.len);
            @memcpy(self.array[self.len..][0..slice.len], slice[0..slice.len]);
            self.len = self.len + slice.len;
        }

        pub fn get_last(self: *Self) T {
            return self.array[self.len - 1];
        }

        pub fn get_at_unsafe(self: *Self, i: usize) T {
            return self.array[i];
        }

        pub fn set(self: *Self, slice: []const T) !void {
            self.reset();
            try self.extend(slice);
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
            @memcpy(dst[i_dst_shift..][0..i_end], self.array[0..i_end]);
        }

        pub fn check_is_equal(self: *Self, other: *const Self) bool {
            if (self.len != other.len) return false;
            for (self.array[0..self.len], 0..) |elem, i| {
                if (elem != other.array[i])
                    return false;
            }
            return true;
        }

        pub fn print_debug(self: *const Self) void {
            std.debug.print("{any}\n", .{self.array[0..self.len]});
        }

        pub fn ensureCapacity(self: *Self, capacity: usize) !void {
            if (self.capacity >= capacity) return;
            const new_capacity = capacity * 2;
            if (self.allocator.remap(self.array, new_capacity)) |new_memory| {
                self.array = new_memory;
                self.capacity = new_capacity;
            } else {
                const new_memory = try self.allocator.alloc(T, new_capacity);
                @memcpy(new_memory[0..self.len], self.array[0..self.len]);
                self.allocator.free(self.array);
                self.array = new_memory;
                self.capacity = new_capacity;
            }
        }
    };
}
