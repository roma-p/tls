const std = @import("std");
const string_on_stack = @import("string_on_stack.zig");
const constants = @import("constants.zig");

pub fn format_sequence(
    pattern_before: []const u8,
    pattern_after: []const u8,
    ptr_sequence_array: *[constants.MAX_LEN_FOR_SEQUENCE_SPLIT]u16,
    split_nbr: usize,
    str_out: *string_on_stack.StringOnStack(constants.MAX_STR_LEN_ENTRY),
) !void {
    str_out.append_string(pattern_before);
    try format_sequence_number_part(ptr_sequence_array, split_nbr, str_out);
    str_out.append_string(pattern_after);
}

fn format_sequence_number_part(
    ptr_sequence_array: *[constants.MAX_LEN_FOR_SEQUENCE_SPLIT]u16,
    split_nbr: usize,
    str_out: *string_on_stack.StringOnStack(constants.MAX_STR_LEN_ENTRY),
) !void {
    if (ptr_sequence_array.*.len < 2) return;
    if (split_nbr < 1) return;

    var is_buffering: bool = true;
    var buffer_isolated_files: [3]u16 = [_]u16{ 0, 0, 0 };
    var buffer_isolated_files_i: usize = 0;
    var buffer_first_file: u16 = 0;
    var buffer_last_file: u16 = 0;

    buffer_first_file = ptr_sequence_array.*[0];
    buffer_last_file = buffer_first_file + ptr_sequence_array.*[1];

    var i: usize = 0;
    var j: usize = 0;

    str_out.append_char('[');

    while (i < split_nbr) : (i += 1) {
        j = i * 2;
        const val_0 = ptr_sequence_array.*[j];
        const val_1 = ptr_sequence_array.*[j + 1];

        if (val_0 == buffer_last_file + 2) {
            if (buffer_isolated_files_i >= buffer_isolated_files.len) {} else {
                buffer_isolated_files[buffer_isolated_files_i] = val_0 - 1;
            }
            buffer_last_file = val_0 + val_1;
            buffer_isolated_files_i += 1;
        }

        // collecting
        if (i > split_nbr - 1 or val_0 > buffer_last_file + 2) {
            try collect(
                str_out,
                buffer_first_file,
                buffer_last_file,
                &buffer_isolated_files,
                buffer_isolated_files_i,
            );
            is_buffering = false;
            buffer_isolated_files_i = 0;
            buffer_first_file = val_0;
            buffer_last_file = val_0 + val_1;
        }
    }
    try collect(
        str_out,
        buffer_first_file,
        buffer_last_file,
        &buffer_isolated_files,
        buffer_isolated_files_i,
    );
    str_out.trim_str(1);
    str_out.append_char(']');
}

fn collect(
    str_out: *string_on_stack.StringOnStack(constants.MAX_STR_LEN_ENTRY),
    first_file: u16,
    last_file: u16,
    buffer_isolated_files: *[constants.MAX_DISPLAYED_ISOLATED_FILE]u16,
    buffer_isolated_files_i: usize,
) !void {
    if (first_file == last_file) {
        try str_out.append_number(u16, first_file, null);
    } else {
        try str_out.append_number(u16, first_file, null);
        str_out.append_char(':');
        try str_out.append_number(u16, last_file, null);
    }
    if (buffer_isolated_files_i > buffer_isolated_files.len) {
        str_out.append_string("??");
    } else {
        str_out.append_char('?');
        var k: usize = 0;
        while (k < buffer_isolated_files_i) : (k += 1) {
            try str_out.append_number(u16, buffer_isolated_files[k], null);
            str_out.append_char(',');
        }
        str_out.trim_str(1);
    }
    str_out.append_char(' ');
}

test "format_sequence_number_part" {
    var terminal_string_output = string_on_stack.StringOnStack(constants.MAX_STR_LEN_ENTRY).init();

    var arr_2 = [_]u16{ 3, 2, 10, 4 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 4);
    try format_sequence_number_part(&arr_2, 2, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "[3:5 10:14]",
        terminal_string_output.get_slice(),
    );
    terminal_string_output.reset();

    var arr_3 = [_]u16{ 3, 2 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 2);
    try format_sequence_number_part(&arr_3, 2, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "[3:5]",
        terminal_string_output.get_slice(),
    );
    terminal_string_output.reset();

    var arr_4 = [_]u16{ 3, 2, 10, 4, 43, 0, 50, 2 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 8);
    try format_sequence_number_part(&arr_4, 4, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "[3:5 10:14 43 50:52]",
        terminal_string_output.get_slice(),
    );
    terminal_string_output.reset();

    var arr_5 = [_]u16{ 3, 2, 7, 0 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 4);
    try format_sequence_number_part(&arr_5, 2, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "[3:7?6]",
        terminal_string_output.get_slice(),
    );
    terminal_string_output.reset();

    var arr_6 = [_]u16{ 3, 2, 7, 0, 9, 2, 13, 2, 20, 0, 25, 0, 30, 2 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 14);
    try format_sequence_number_part(&arr_6, 7, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "[3:15?6,8,12 20 25 30:32]",
        terminal_string_output.get_slice(),
    );
    terminal_string_output.reset();

    var arr_7 = [_]u16{ 3, 2, 7, 0, 9, 1, 12, 3, 17, 2 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 10);
    try format_sequence_number_part(&arr_7, 5, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "[3:19??]",
        terminal_string_output.get_slice(),
    );
    terminal_string_output.reset();
}

test "format_sequence" {
    var terminal_string_output = string_on_stack.StringOnStack(constants.MAX_STR_LEN_ENTRY).init();
    var arr_2 = [_]u16{ 3, 2, 10, 4 } ++ [_]u16{0} ** (constants.MAX_LEN_FOR_SEQUENCE_SPLIT - 4);
    const pattern_before = "089_06_surf-v001.";
    const pattern_after = ".exr";
    try format_sequence(pattern_before, pattern_after, &arr_2, 2, &terminal_string_output);
    try std.testing.expectEqualSlices(
        u8,
        "089_06_surf-v001.[3:5 10:14].exr",
        terminal_string_output.get_slice(),
    );
}
