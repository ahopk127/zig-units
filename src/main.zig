const std = @import("std");
const lib = @import("units_lib");

const units = lib.units;
const db = lib.db;

const length: [9]i16 = .{ 0, 1, 0, 0, 0, 0, 0, 0, 0 };
const millimetre: units.Linear = .{ .magnitude = 1e-3, .dimension = length };
const metre: units.Linear = .{ .magnitude = 1e0, .dimension = length };
const kilometre: units.Linear = .{ .magnitude = 1e3, .dimension = length };

pub fn main() !void {
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

    try units_db.units.put("m", metre);
    try units_db.units.put("km", kilometre);

    const result = try units_db.convert(10000, "m", "km");
    try stdout.print("10000 m = {} km\n", .{result});

    try bw.flush(); // Don't forget to flush!
}
