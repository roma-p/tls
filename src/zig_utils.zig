

pub fn copy_arr(comptime T: type, src: []const T, dst: []T, len:usize) void {
    var i: usize = 0;
    while (i < len): (i+=1) {
        dst[i] = src[i];
    }
}
