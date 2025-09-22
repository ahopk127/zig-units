const std = @import("std");
const lib = @import("units_lib");

const units = lib.units;
const db = lib.db;

const length: [9]i16 = .{ 0, 1, 0, 0, 0, 0, 0, 0, 0 };
const volume: [9]i16 = .{ 0, 3, 0, 0, 0, 0, 0, 0, 0 };
const time: [9]i16 = .{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };

const metre: units.Linear = .{ .magnitude = 1e0, .dimension = length };
const litre: units.Linear = .{ .magnitude = 1e-3, .dimension = volume };
const second: units.Linear = .{ .magnitude = 1e0, .dimension = time };
const hour: units.Linear = second.scaledBy(3.6e3);

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
    try units_db.prefixes.put("μ", 1e-6);
    try units_db.prefixes.put("u", 1e-6);
    try units_db.prefixes.put("m", 1e-3);
    try units_db.prefixes.put("k", 1e3);
    try units_db.prefixes.put("M", 1e6);

    const kilometre = try units_db.get_unit("km");

    try units_db.units.put("m^3", metre.toExponent(3));
    try units_db.units.put("L", litre);
    try units_db.units.put("m/s", metre.dividedBy(second));
    try units_db.units.put("km/h", kilometre.dividedBy(hour));

    const result1 = try units_db.convert(15, "m/s", "km/h");
    try stdout.print("15 m/s = {d:.0} km/h\n", .{result1});
    const result2 = try units_db.convert(0.35, "m^3", "L");
    try stdout.print("0.35 m^3 = {d:.0} L\n", .{result2});
    const result3 = try units_db.convert(15, "Mm", "um");
    try stdout.print("15 Mm = {} μm\n", .{result3});

    try bw.flush(); // Don't forget to flush!
}
