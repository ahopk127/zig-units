const std = @import("std");
const lib = @import("units_lib");

const length: [9]i16 = .{ 1, 0, 0, 0, 0, 0, 0, 0, 0 };
const millimetre: lib.LinearUnit = .{ .magnitude = 1e-3, .dimension = length };
const metre: lib.LinearUnit = .{ .magnitude = 1e0, .dimension = length };
const kilometre: lib.LinearUnit = .{ .magnitude = 1e3, .dimension = length };

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const result = try lib.convert(10000, metre, kilometre);
    try stdout.print("10000 m = {} km\n", .{result});

    try bw.flush(); // Don't forget to flush!
}
