const std = @import("std");
const lib = @import("units_lib");

const units = lib.units;
const db = lib.db;

const Args = struct { round: bool };

fn parse_args(allocator: std.mem.Allocator) !Args {
    var args: Args = .{ .round = true };

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-e")) {
            args.round = false;
        }
    }

    return args;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak)
            std.debug.print("Memory leak detected\n", .{});
    }

    const args = try parse_args(allocator);

    const stdin_file = std.io.getStdIn().reader();
    var br = std.io.bufferedReader(stdin_file);
    const stdin = br.reader();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var units_db = db.new(allocator);
    defer units_db.free(allocator);
    try units_db.load_file("unitfile", allocator);

    try stdout.print("Enter value to convert from: ", .{});
    try bw.flush();
    var input_buf1: [256]u8 = undefined;
    const amt1 = try stdin.read(&input_buf1);
    const from = std.mem.trimRight(u8, input_buf1[0..amt1], "\r\n");

    try stdout.print("Enter unit to convert to: ", .{});
    try bw.flush();
    var input_buf2: [256]u8 = undefined;
    const amt2 = try stdin.read(&input_buf2);
    const to = std.mem.trimRight(u8, input_buf2[0..amt2], "\r\n");

    const result = try units_db.convert_expression(from, to);
    if (args.round) {
        try stdout.print("{s} = {d:.0} {s}\n", .{ from, result, to });
    } else {
        try stdout.print("{s} = {e:.12} {s}\n", .{ from, result, to });
    }
    try bw.flush();
}
