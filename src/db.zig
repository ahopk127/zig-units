const std = @import("std");

const units = @import("units.zig");

pub const UnitNotFound = error.UnitNotFound;
pub const PrefixNotFound = error.PrefixNotFound;
pub const InvalidLineFormat = error{ TooFewElements, InvalidLineType, InvalidBaseIndex };

const MAX_LINE_LENGTH = 65536;

pub const UnitDatabase = struct {
    units: std.StringHashMap(units.Linear),
    prefixes: std.StringHashMap(f64),
    names: std.ArrayList([]const u8),
    pub fn convert(self: *UnitDatabase, value: f64, from: []const u8, to: []const u8) !f64 {
        const fromUnit = try self.get_unit(from);
        const toUnit = try self.get_unit(to);
        return try units.convert(value, fromUnit, toUnit);
    }
    pub fn convert_expression(self: *UnitDatabase, from: []const u8, to: []const u8) !f64 {
        const fromUnit = try self.parse_unit_expression(from);
        const toUnit = try self.parse_unit_expression(to);
        return try units.convert(1.0, fromUnit, toUnit);
    }
    pub fn get_unit(self: *UnitDatabase, name: []const u8) ?units.Linear {
        if (self.units.get(name)) |unit| {
            return unit;
        } else if (name.len < 1) {
            // An empty string will cause 'i' to overflow, since it's a usize
            return null;
        }

        var i = name.len - 1;
        while (i > 0) : (i -= 1) {
            const prefix = self.prefixes.get(name[0..i]) orelse continue;
            const unit = self.get_unit(name[i..name.len]) orelse continue;
            return unit.scaledBy(prefix);
        }

        std.debug.print("Unknown unit '{s}'.\n", .{name});
        return null;
    }
    fn get_unit_or_number(self: *UnitDatabase, name: []const u8) ?units.Linear {
        if (std.fmt.parseFloat(f64, name)) |n| {
            return units.ONE.scaledBy(n);
        } else |_| {
            return self.get_unit(name);
        }
    }
    fn get_prefix_or_number(self: *UnitDatabase, name: []const u8) ?f64 {
        if (std.fmt.parseFloat(f64, name)) |n| {
            return n;
        } else |_| {
            return self.prefixes.get(name);
        }
    }
    fn parse_unit_exponent(self: *UnitDatabase, name: []const u8) !units.Linear {
        if (std.mem.indexOfScalar(u8, name, '^')) |expIndex| {
            const unit = self.get_unit_or_number(name[0..expIndex]) orelse return UnitNotFound;
            const exponent = try std.fmt.parseInt(i16, name[expIndex + 1 .. name.len], 10);
            return unit.toExponent(exponent);
        } else {
            return self.get_unit_or_number(name) orelse UnitNotFound;
        }
    }
    fn parse_prefix_exponent(self: *UnitDatabase, name: []const u8) !f64 {
        if (std.mem.indexOfScalar(u8, name, '^')) |expIndex| {
            const prefix = self.get_prefix_or_number(name[0..expIndex]) orelse return PrefixNotFound;
            const exponent = try std.fmt.parseFloat(f64, name[expIndex + 1 .. name.len]);
            return std.math.pow(f64, prefix, exponent);
        } else {
            return self.get_prefix_or_number(name) orelse PrefixNotFound;
        }
    }
    fn parse_unit_fraction(self: *UnitDatabase, name: []const u8) !units.Linear {
        if (std.mem.indexOfScalar(u8, name, '/')) |slashIndex| {
            const numerator = if (slashIndex == 0) units.ONE else try self.parse_unit_exponent(name[0..slashIndex]);
            const denominator = try self.parse_unit_exponent(name[slashIndex + 1 .. name.len]);
            return numerator.dividedBy(denominator);
        } else {
            return self.parse_unit_exponent(name);
        }
    }
    fn parse_prefix_fraction(self: *UnitDatabase, name: []const u8) !f64 {
        if (std.mem.indexOfScalar(u8, name, '/')) |slashIndex| {
            const numerator = try self.parse_prefix_exponent(name[0..slashIndex]);
            const denominator = try self.parse_prefix_exponent(name[slashIndex + 1 .. name.len]);
            return numerator / denominator;
        } else {
            return self.parse_prefix_exponent(name);
        }
    }
    pub fn parse_unit_expression(self: *UnitDatabase, name: []const u8) !units.Linear {
        var product = units.ONE;
        var it = std.mem.splitScalar(u8, name, ' ');
        while (it.next()) |el| {
            if (el.len == 0) continue;

            const unit = try self.parse_unit_fraction(el);
            product = product.times(unit);
        }

        return product;
    }
    pub fn parse_prefix_expression(self: *UnitDatabase, name: []const u8) !f64 {
        var product: f64 = 1.0;
        var it = std.mem.splitScalar(u8, name, ' ');
        while (it.next()) |el| {
            if (el.len == 0) continue;
            product *= try self.parse_prefix_fraction(el);
        }
        return product;
    }
    pub fn eval_line(self: *UnitDatabase, line: []const u8, allocator: std.mem.Allocator) !void {
        const first_space = std.mem.indexOfAny(u8, line, " \t") orelse return InvalidLineFormat.TooFewElements;
        const second_space = std.mem.indexOfAnyPos(u8, line, first_space + 1, " \t") orelse return InvalidLineFormat.TooFewElements;

        const name = try allocator.dupe(u8, line[0..first_space]);
        try self.names.append(name);

        const line_type = line[first_space + 1 .. second_space];
        const value = line[second_space + 1 .. line.len];

        if (std.mem.eql(u8, line_type, "base")) {
            const index = try std.fmt.parseInt(usize, value, 10);
            if (index >= units.NUM_DIMENSIONS) {
                return InvalidLineFormat.InvalidBaseIndex;
            }
            var dimension = [_]i16{0} ** units.NUM_DIMENSIONS;
            dimension[index] = 1;
            const unit = units.Linear{ .magnitude = 1.0, .dimension = dimension };
            try self.units.put(name, unit);
        } else if (std.mem.eql(u8, line_type, "alias")) {
            const unit = self.get_unit(value) orelse return UnitNotFound;
            try self.units.put(name, unit);
        } else if (std.mem.eql(u8, line_type, "linear")) {
            const unit = try self.parse_unit_expression(value);
            try self.units.put(name, unit);
        } else if (std.mem.eql(u8, line_type, "prefix")) {
            const prefix = try self.parse_prefix_expression(value);
            try self.prefixes.put(name, prefix);
        } else {
            std.debug.print("Invalid line: '{s}'\n", .{line});
            return InvalidLineFormat.InvalidLineType;
        }
    }
    pub fn load_file(self: *UnitDatabase, path: []const u8, allocator: std.mem.Allocator) !void {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        const file_stream = buf_reader.reader();
        var line_buf: [MAX_LINE_LENGTH]u8 = undefined;
        while (try file_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
            var commentless_line = line;
            if (std.mem.indexOfScalar(u8, commentless_line, '#')) |index| {
                commentless_line = commentless_line[0..index];
            }
            const trimmed_line = std.mem.trim(u8, commentless_line, " \t\r\n");
            if (trimmed_line.len == 0)
                continue;

            try self.eval_line(trimmed_line, allocator);
        }
    }
    pub fn free(self: *UnitDatabase, allocator: std.mem.Allocator) void {
        self.units.deinit();
        self.prefixes.deinit();
        for (self.names.items) |name| {
            allocator.free(name);
        }
        self.names.deinit();
    }
};

pub fn new(allocator: std.mem.Allocator) UnitDatabase {
    const units_map = std.StringHashMap(units.Linear).init(allocator);
    const prefixes_map = std.StringHashMap(f64).init(allocator);
    const names = std.ArrayList([]const u8).init(allocator);
    return UnitDatabase{ .units = units_map, .prefixes = prefixes_map, .names = names };
}

const test_lines = [_][]const u8{
    "s\tbase\t0",
    "m\tbase\t1",
    "kg\tbase\t2",
    "rad\tbase\t3",
    "k\tprefix\t1e+3",
    "M\tprefix\t1e+6",
    "m\tprefix\t1e-3",
    "μ\tprefix\t1e-6",
    "g\talias\tmkg",
};

test "load units & prefixes" {
    var testdb = new(std.testing.allocator);
    defer testdb.free(std.testing.allocator);
    for (test_lines) |line| {
        try testdb.eval_line(line, std.testing.allocator);
    }

    try std.testing.expectEqual(5, testdb.units.count());
    try std.testing.expectEqual(4, testdb.prefixes.count());

    try std.testing.expectEqual(units.METRE, testdb.get_unit("m"));
    try std.testing.expectEqual(units.SECOND, testdb.get_unit("s"));
    try std.testing.expectEqual(1e+3, testdb.prefixes.get("k"));
    try std.testing.expectEqual(1e-3, testdb.prefixes.get("m"));
}

test "prefixed units" {
    var testdb = new(std.testing.allocator);
    defer testdb.free(std.testing.allocator);
    for (test_lines) |line| {
        try testdb.eval_line(line, std.testing.allocator);
    }

    const Mm = units.METRE.scaledBy(1e+6);
    const km = units.METRE.scaledBy(1e+3);
    const mm = units.METRE.scaledBy(1e-3);
    const um = units.METRE.scaledBy(1e-6);
    try std.testing.expectEqual(Mm, testdb.get_unit("kkm"));
    try std.testing.expectEqual(Mm, testdb.get_unit("Mm"));
    try std.testing.expectEqual(mm, testdb.get_unit("mm"));
    try std.testing.expectEqual(um, testdb.get_unit("μm"));
    try std.testing.expectEqual(km, testdb.get_unit("Mmm"));
}

test "expressions" {
    var testdb = new(std.testing.allocator);
    defer testdb.free(std.testing.allocator);
    for (test_lines) |line| {
        try testdb.eval_line(line, std.testing.allocator);
    }

    const joule = units.Linear{ .magnitude = 1.0, .dimension = [_]i16{ -2, 2, 1, 0, 0, 0, 0, 0, 0 } };
    const joule_expression = "kg m^2/s^2";
    try std.testing.expectEqual(joule, testdb.parse_unit_expression(joule_expression));

    const femtojoule = joule.scaledBy(1e-15);
    const femtojoule_expression = "μg km^2/Ms^2";
    try std.testing.expectEqual(femtojoule, testdb.parse_unit_expression(femtojoule_expression));
}
