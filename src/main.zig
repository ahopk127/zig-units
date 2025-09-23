const std = @import("std");
const lib = @import("units_lib");

const units = lib.units;
const db = lib.db;

const length: [9]i16 = .{ 0, 1, 0, 0, 0, 0, 0, 0, 0 };
const volume: [9]i16 = .{ 0, 3, 0, 0, 0, 0, 0, 0, 0 };
const mass: [9]i16 = .{ 0, 0, 1, 0, 0, 0, 0, 0, 0 };
const time: [9]i16 = .{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };

const metre: units.Linear = .{ .magnitude = 1e0, .dimension = length };
const litre: units.Linear = .{ .magnitude = 1e-3, .dimension = volume };
const second: units.Linear = .{ .magnitude = 1e0, .dimension = time };
const gram: units.Linear = .{ .magnitude = 1e-3, .dimension = mass };

pub fn main() !void {
    const stdin_file = std.io.getStdIn().reader();
    var br = std.io.bufferedReader(stdin_file);
    const stdin = br.reader();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak)
            std.debug.print("Memory leak detected\n", .{});
    }

    var units_db = db.new(allocator);
    defer units_db.free();

    try units_db.eval_line("s\tbase\t0");
    try units_db.eval_line("m\tbase\t1");
    try units_db.eval_line("kg\tbase\t2");

    try units_db.units.put("min", second.scaledBy(60.0));
    try units_db.units.put("hr", second.scaledBy(3600.0));
    try units_db.units.put("g", gram);
    try units_db.units.put("L", litre);

    try units_db.prefixes.put("μ", 1e-6);
    try units_db.prefixes.put("u", 1e-6);
    try units_db.prefixes.put("m", 1e-3);
    try units_db.prefixes.put("k", 1e3);
    try units_db.prefixes.put("M", 1e6);

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
    try stdout.print("{s} = {} {s}\n", .{ from, result, to });
    try bw.flush();
}
