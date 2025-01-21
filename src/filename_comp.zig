const std = @import("std");
const fs = std.fs;

pub fn split_filename_at_numbers(filename: []const u8) struct { [50]usize, usize } {
    var ret = [_]usize{0} ** 50;
    var ret_i: usize = 0;
    var last_c_type: u1 = 0; // 0: alpha, 1: digit
    for (filename, 0..) |c, i| {
        const current_c_type: u1 = if (std.ascii.isDigit(c)) 1 else 0;
        if (last_c_type != current_c_type) {
            ret[ret_i] = i;
            ret_i += 1;
            if (ret_i == 50) {
                ret[ret_i] = filename.len;
                ret_i += 1;
                return .{ ret, ret_i };
            }
        }
        last_c_type = current_c_type;
    }
    ret[ret_i] = filename.len;
    ret_i += 1;
    return .{ ret, ret_i };
}

pub fn check_is_sequence_using_two_filenames(
    filename_1: []const u8,
    filename_2: []const u8,
) !struct { u1, usize, usize, u16, u16 } {
    // u1 : bool (0: is sequence, 1 not sequence)
    // usize: idx of filename_1 and _2 where number start.
    // usize: idx of filename_1 where number ends.
    // u16: sequence number on filename_1
    // u16: sequence number on filename_2

    const ret_not_a_sequence = .{ 1, 0, 0, 0, 0 };

    var diff_number_found: bool = false;
    var diff_number_start_idx: usize = 0;
    var diff_number_end_idx_filename_1: usize = 0;
    var number_1: u16 = 0;
    var number_2: u16 = 0;

    const split_info_file_1 = split_filename_at_numbers(filename_1);
    const split_info_file_2 = split_filename_at_numbers(filename_2);

    if (split_info_file_1.@"1" != split_info_file_2.@"1") {
        return ret_not_a_sequence;
    }
    const split_number = split_info_file_1.@"1";

    const split_file_1 = split_info_file_1.@"0";
    const split_file_2 = split_info_file_2.@"0";

    var it_array_of_split: usize = 0;
    var buffer_last_split_idx_file_1: usize = 0;
    var buffer_last_split_idx_file_2: usize = 0;
    var last_c_type: u1 = 0; // 0: alpha, 1: digit
    while (it_array_of_split < split_number) : (it_array_of_split += 1) {
        const split_idx_file_1 = split_file_1[it_array_of_split];
        const split_idx_file_2 = split_file_2[it_array_of_split];

        const slice_1 = filename_1[buffer_last_split_idx_file_1..split_idx_file_1];
        const slice_2 = filename_2[buffer_last_split_idx_file_2..split_idx_file_2];

        if (last_c_type == 0) {
            if (!std.mem.eql(u8, slice_1, slice_2)) return ret_not_a_sequence;
        } else {
            if (!std.mem.eql(u8, slice_1, slice_2)) {
                const nbr_1 = try std.fmt.parseInt(u16, slice_1, 10);
                const nbr_2 = try std.fmt.parseInt(u16, slice_2, 10);

                if (nbr_1 != nbr_2) {
                    if (diff_number_found) {
                        // can not have multiple diff number in filenames in a seq.
                        return ret_not_a_sequence;
                    } else {
                        diff_number_found = true;
                        diff_number_start_idx = buffer_last_split_idx_file_1;
                        diff_number_end_idx_filename_1 = split_idx_file_1;
                        number_1 = nbr_1;
                        number_2 = nbr_2;
                        // in that case we know
                        // buffer_last_split_idx_file_1 == buffer_last_split_idx_file_2
                    }
                }
            }
        }

        last_c_type = if (last_c_type == 0) 1 else 0;
        buffer_last_split_idx_file_1 = split_idx_file_1;
        buffer_last_split_idx_file_2 = split_idx_file_2;
    }
    if (!diff_number_found) return ret_not_a_sequence;
    return .{
        0,
        diff_number_start_idx,
        diff_number_end_idx_filename_1,
        number_1,
        number_2,
    };
}

pub fn check_file_belong_to_sequence(
    filename: []const u8,
    pattern_before: []const u8,
    pattern_after: []const u8,
) !?u16 {
    if (filename.len < (pattern_before.len + 1 + pattern_after.len)) {
        return null;
    }
    if (filename.len < pattern_before.len) {
        return null;
    }
    if (!std.mem.eql(u8, pattern_before, filename[0..pattern_before.len])) {
        return null;
    }
    if (!std.ascii.isDigit(filename[pattern_before.len])) {
        return null;
    }
    var i: usize = pattern_before.len + 1;
    while (i < filename.len) : (i += 1) {
        if (!std.ascii.isDigit(filename[i])) {
            break;
        }
    }
    const ret = try std.fmt.parseInt(u16, filename[pattern_before.len..i], 10);
    if (filename.len - i != pattern_after.len) {
        return null;
    }
    if (!std.mem.eql(u8, pattern_after, filename[i..])) {
        return null;
    }
    return ret;
}

///////////////////////////////////////////////////////////////////////////////

test "check_is_sequence_using_two_filenames" {
    // todo: remove this try

    // test valid image sequence
    const test_1 = try check_is_sequence_using_two_filenames(
        "trucv001.001.exr",
        "trucv001.002.exr",
    );
    try std.testing.expectEqual(0, test_1.@"0");
    try std.testing.expectEqual(9, test_1.@"1");
    try std.testing.expectEqual(12, test_1.@"2");
    try std.testing.expectEqual(1, test_1.@"3");
    try std.testing.expectEqual(2, test_1.@"4");

    const test_2 = try check_is_sequence_using_two_filenames(
        "trucv001.001.exr",
        "trucv001.2.exr",
    );
    try std.testing.expectEqual(0, test_2.@"0");
    try std.testing.expectEqual(9, test_2.@"1");
    try std.testing.expectEqual(12, test_2.@"2");
    try std.testing.expectEqual(1, test_2.@"3");
    try std.testing.expectEqual(2, test_2.@"4");

    const test_3 = try check_is_sequence_using_two_filenames(
        "trucv001.001.exr",
        "trucv001.0010.exr",
    );
    try std.testing.expectEqual(0, test_3.@"0");
    try std.testing.expectEqual(9, test_3.@"1");
    try std.testing.expectEqual(12, test_3.@"2");
    try std.testing.expectEqual(1, test_3.@"3");
    try std.testing.expectEqual(10, test_3.@"4");

    const test_4 = try check_is_sequence_using_two_filenames(
        "trucv001.4.exr",
        "trucv001.150.exr",
    );
    try std.testing.expectEqual(0, test_4.@"0");
    try std.testing.expectEqual(9, test_4.@"1");
    try std.testing.expectEqual(10, test_4.@"2");
    try std.testing.expectEqual(4, test_4.@"3");
    try std.testing.expectEqual(150, test_4.@"4");

    // test unvalid image sequence
    const test_5 = try check_is_sequence_using_two_filenames(
        "trucv001.001.exr",
        "trucv002.002.exr",
    );
    try std.testing.expectEqual(1, test_5.@"0");

    const test_6 = try check_is_sequence_using_two_filenames(
        "trucv1.001.exr",
        "trucv10.002.exr",
    );
    try std.testing.expectEqual(1, test_6.@"0");

    const test_7 = try check_is_sequence_using_two_filenames(
        "trucv001.001.c4d",
        "trucv002.002.exr",
    );
    try std.testing.expectEqual(1, test_7.@"0");

    // test when seq is beginning.
    const test_8 = try check_is_sequence_using_two_filenames(
        "001.trucv001.001.exr",
        "002.trucv001.001.exr",
    );
    try std.testing.expectEqual(0, test_8.@"0");
    try std.testing.expectEqual(0, test_8.@"1");
    try std.testing.expectEqual(3, test_8.@"2");
    try std.testing.expectEqual(1, test_8.@"3");
    try std.testing.expectEqual(2, test_8.@"4");

    const test_9 = try check_is_sequence_using_two_filenames(
        "001.trucv001.001.exr",
        "002.trucv002.001.exr",
    );
    try std.testing.expectEqual(1, test_9.@"0");

    // test real prod usecase
    const test_10 = try check_is_sequence_using_two_filenames(
        "089_06_surf-v001.0040.exr",
        "089_06_surf-v001.0041.exr",
    );
    try std.testing.expectEqual(0, test_10.@"0");
    try std.testing.expectEqual(17, test_10.@"1");
    try std.testing.expectEqual(21, test_10.@"2");
    try std.testing.expectEqual(40, test_10.@"3");
    try std.testing.expectEqual(41, test_10.@"4");

    const test_11 = try check_is_sequence_using_two_filenames(
        "089_06_surf-v001.ma",
        "089_06_surf-v002.ma",
    );
    try std.testing.expectEqual(0, test_11.@"0");
    try std.testing.expectEqual(13, test_11.@"1");
    try std.testing.expectEqual(16, test_11.@"2");
    try std.testing.expectEqual(1, test_11.@"3");
    try std.testing.expectEqual(2, test_11.@"4");
}

test "split_filename_at_numbers" {
    const test_1 = split_filename_at_numbers("trucv001.001.exr");
    try std.testing.expectEqual(5, test_1.@"1");
    try std.testing.expectEqual([_]usize{ 5, 8, 9, 12, 16 }, test_1.@"0"[0..5].*);

    const test_2 = split_filename_at_numbers("trucv001.001.040_valid_3.exr");
    try std.testing.expectEqual([_]usize{ 5, 8, 9, 12, 13, 16, 23, 24, 28 }, test_2.@"0"[0..9].*);
    try std.testing.expectEqual(9, test_2.@"1");

    const test_3 = split_filename_at_numbers("089_06_surf-v001.0040.exr");
    try std.testing.expectEqual(9, test_3.@"1");
    try std.testing.expectEqual([_]usize{ 0, 3, 4, 6, 13, 16, 17, 21, 25 }, test_3.@"0"[0..9].*);
}

test "check_file_belong_to_sequence" {
    try std.testing.expectEqual(
        40,
        try check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001.",
            ".exr",
        ),
    );
    try std.testing.expectEqual(
        null,
        try check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001....",
            ".exr",
        ),
    );
    try std.testing.expectEqual(
        null,
        try check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v0",
            ".exr-",
        ),
    );
    try std.testing.expectEqual(
        null,
        try check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surv-v001.",
            ".exr",
        ),
    );
    try std.testing.expectEqual(
        null,
        try check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001.",
            ".exd",
        ),
    );
}
