const std = @import("std");
const fs = std.fs;

pub const ResultCheckIsSequenceUsingTwoFilenames = struct {
    number_start_idx: usize, // idx of filename_1 and _2 where number start.
    number_end_idx_filename_1: usize, // idx of filename_1 and _2 where number start.
    seq_number_filenam_1: u16, // sequence number on filename_1
    seq_number_filenam_2: u16, // sequence number on filename_2
};

pub fn check_is_sequence_using_two_filenames(
    filename_1: []const u8,
    filename_2: []const u8,
) ?ResultCheckIsSequenceUsingTwoFilenames {
    var diff_number_found: bool = false;
    var diff_number_start_idx: usize = 0;
    var diff_number_end_idx_filename_1: usize = 0;
    var number_1: u16 = 0;
    var number_2: u16 = 0;

    const split_info_file_1 = _split_filename_at_numbers(filename_1);
    const split_info_file_2 = _split_filename_at_numbers(filename_2);

    if (split_info_file_1.@"1" != split_info_file_2.@"1") {
        return null;
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
            if (!std.mem.eql(u8, slice_1, slice_2)) return null;
        } else {
            if (!std.mem.eql(u8, slice_1, slice_2)) {
                const nbr_1 = std.fmt.parseInt(u16, slice_1, 10) catch unreachable;
                const nbr_2 = std.fmt.parseInt(u16, slice_2, 10) catch unreachable;

                if (nbr_1 != nbr_2) {
                    if (diff_number_found) {
                        // can not have multiple diff number in filenames in a seq.
                        return null;
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
    if (!diff_number_found) return null;
    return ResultCheckIsSequenceUsingTwoFilenames{
        .number_start_idx = diff_number_start_idx,
        .number_end_idx_filename_1 = diff_number_end_idx_filename_1,
        .seq_number_filenam_1 = number_1,
        .seq_number_filenam_2 = number_2,
    };
}

pub fn check_file_belong_to_sequence(
    filename: []const u8,
    pattern_before: []const u8,
    pattern_after: []const u8,
) ?u16 {
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
    const ret = std.fmt.parseInt(u16, filename[pattern_before.len..i], 10) catch unreachable;
    if (filename.len - i != pattern_after.len) {
        return null;
    }
    if (!std.mem.eql(u8, pattern_after, filename[i..])) {
        return null;
    }
    return ret;
}

fn _split_filename_at_numbers(filename: []const u8) struct { [50]usize, usize } {
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

///////////////////////////////////////////////////////////////////////////////

test "check_is_sequence_using_two_filenames" {
    // todo: remove this try

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 9,
            .number_end_idx_filename_1 = 12,
            .seq_number_filenam_1 = 1,
            .seq_number_filenam_2 = 2,
        },
        check_is_sequence_using_two_filenames(
            "trucv001.001.exr",
            "trucv001.002.exr",
        ).?,
    );

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 9,
            .number_end_idx_filename_1 = 12,
            .seq_number_filenam_1 = 1,
            .seq_number_filenam_2 = 2,
        },
        check_is_sequence_using_two_filenames(
            "trucv001.001.exr",
            "trucv001.2.exr",
        ).?,
    );

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 9,
            .number_end_idx_filename_1 = 12,
            .seq_number_filenam_1 = 1,
            .seq_number_filenam_2 = 10,
        },
        check_is_sequence_using_two_filenames(
            "trucv001.001.exr",
            "trucv001.0010.exr",
        ).?,
    );

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 9,
            .number_end_idx_filename_1 = 10,
            .seq_number_filenam_1 = 4,
            .seq_number_filenam_2 = 150,
        },
        check_is_sequence_using_two_filenames(
            "trucv001.4.exr",
            "trucv001.150.exr",
        ).?,
    );

    // test unvalid image sequence
    const test_5 = check_is_sequence_using_two_filenames(
        "trucv001.001.exr",
        "trucv002.002.exr",
    );
    try std.testing.expectEqual(null, test_5);

    const test_6 = check_is_sequence_using_two_filenames(
        "trucv1.001.exr",
        "trucv10.002.exr",
    );
    try std.testing.expectEqual(null, test_6);

    const test_7 = check_is_sequence_using_two_filenames(
        "trucv001.001.c4d",
        "trucv002.002.exr",
    );
    try std.testing.expectEqual(null, test_7);

    // test when seq is beginning.

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 0,
            .number_end_idx_filename_1 = 3,
            .seq_number_filenam_1 = 1,
            .seq_number_filenam_2 = 2,
        },
        check_is_sequence_using_two_filenames(
            "001.trucv001.001.exr",
            "002.trucv001.001.exr",
        ).?,
    );

    const test_9 = check_is_sequence_using_two_filenames(
        "001.trucv001.001.exr",
        "002.trucv002.001.exr",
    );
    try std.testing.expectEqual(null, test_9);

    // test real prod usecase

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 17,
            .number_end_idx_filename_1 = 21,
            .seq_number_filenam_1 = 40,
            .seq_number_filenam_2 = 41,
        },
        check_is_sequence_using_two_filenames(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001.0041.exr",
        ).?,
    );

    try std.testing.expectEqual(
        ResultCheckIsSequenceUsingTwoFilenames{
            .number_start_idx = 13,
            .number_end_idx_filename_1 = 16,
            .seq_number_filenam_1 = 1,
            .seq_number_filenam_2 = 2,
        },
        check_is_sequence_using_two_filenames(
            "089_06_surf-v001.ma",
            "089_06_surf-v002.ma",
        ).?,
    );
}

test "split_filename_at_numbers" {
    const test_1 = _split_filename_at_numbers("trucv001.001.exr");
    try std.testing.expectEqual(5, test_1.@"1");
    try std.testing.expectEqual([_]usize{ 5, 8, 9, 12, 16 }, test_1.@"0"[0..5].*);

    const test_2 = _split_filename_at_numbers("trucv001.001.040_valid_3.exr");
    try std.testing.expectEqual([_]usize{ 5, 8, 9, 12, 13, 16, 23, 24, 28 }, test_2.@"0"[0..9].*);
    try std.testing.expectEqual(9, test_2.@"1");

    const test_3 = _split_filename_at_numbers("089_06_surf-v001.0040.exr");
    try std.testing.expectEqual(9, test_3.@"1");
    try std.testing.expectEqual([_]usize{ 0, 3, 4, 6, 13, 16, 17, 21, 25 }, test_3.@"0"[0..9].*);
}

test "check_file_belong_to_sequence" {
    try std.testing.expectEqual(
        40,
        check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001.",
            ".exr",
        ),
    );
    try std.testing.expectEqual(
        null,
        check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001....",
            ".exr",
        ),
    );
    try std.testing.expectEqual(
        null,
        check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v0",
            ".exr-",
        ),
    );
    try std.testing.expectEqual(
        null,
        check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surv-v001.",
            ".exr",
        ),
    );
    try std.testing.expectEqual(
        null,
        check_file_belong_to_sequence(
            "089_06_surf-v001.0040.exr",
            "089_06_surf-v001.",
            ".exd",
        ),
    );
}
