const std = @import("std");
const TermWriter = @import("../TermWriter.zig");

pub const EntryColor = enum {
    
    // Add type of file here. 
    Dcc,
    Image,
    Cache,

    // Add extension to type of file here.
    const type_to_ext = .{
        .Image = .{ "exr", "jpg", "jpeg", "png" },
        .Dcc   = .{ "ma",  "nk",  "hip",  "c4d" },
        .Cache = .{ "ass", "abc", "fbx",  "usd" },
    };

    // Assign coloring to a type of file here.
    fn type_to_color(self: EntryColor) TermWriter.Color {
        return switch (self) {
            .Dcc => .Magenta,
            .Image => .Green,
            .Cache => .Red,
        };
    }

    // Main runtime api: return color for given ext.
    pub fn color_from_ext(ext: []const u8) ?TermWriter.Color {
        inline for (EntryColor.ext_to_color) |pair| {
            if (std.mem.eql(u8, ext, pair[0])) return pair[1];
        }
        return null;
    }

    // below is creating a ext -> color map at compilation time.
    const ext_to_color_pair = struct{[]const u8, TermWriter.Color};
    const ext_to_color = build_ext_to_color(type_to_ext);
    fn build_ext_to_color(comptime map: anytype) []const ext_to_color_pair{
        comptime {
            const fields = @typeInfo(@TypeOf(map)).@"struct".fields;
            
            var count = 0;
            for (fields) |f| {
                const tuple = @field(map, f.name);
                count += @typeInfo(@TypeOf(tuple)).@"struct".fields.len;
            }

            var ret: [count]ext_to_color_pair = undefined;

            var i = 0;
            for (fields) |f| {
                const tuple = @field(map, f.name);
                const tuple_fields = @typeInfo(@TypeOf(tuple)).@"struct".fields;
                for (tuple_fields) |tf| {
                    ret[i] = .{@field(tuple, tf.name), type_to_color(@field(EntryColor, f.name))};
                    i += 1;
                }
            }
            const final = ret;
            return &final;
        }
    }
};
