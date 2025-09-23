const std = @import("std");

const units = @import("units.zig");

pub const UnitNotFound = error.UnitNotFound;

pub const UnitDatabase = struct {
    units: std.StringHashMap(units.Linear),
    prefixes: std.StringHashMap(f64),
    pub fn convert(self: *UnitDatabase, value: f64, from: []const u8, to: []const u8) !f64 {
        const fromUnit = try self.get_unit(from);
        const toUnit = try self.get_unit(to);
        return try units.convert(value, fromUnit, toUnit);
    }
    pub fn convert_expression(self: *UnitDatabase, from: []const u8, to: []const u8) !f64 {
        const fromUnit = try self.parse_expression(from);
        const toUnit = try self.parse_expression(to);
        return try units.convert(1.0, fromUnit, toUnit);
    }
    pub fn get_unit(self: *UnitDatabase, name: []const u8) !units.Linear {
        if (self.units.get(name)) |unit| {
            return unit;
        }

        var i = name.len - 1;
        while (i > 0) : (i -= 1) {
            if (self.try_prefix(name[0..i], name[i..name.len])) |unit| {
                return unit;
            }
        }

        std.debug.print("Unknown unit '{s}'.\n", .{name});
        return UnitNotFound;
    }
    fn get_unit_or_number(self: *UnitDatabase, name: []const u8) !units.Linear {
        if (std.fmt.parseFloat(f64, name)) |n| {
            return units.ONE.scaledBy(n);
        } else |_| {
            return self.get_unit(name);
        }
    }
    fn parse_exponent(self: *UnitDatabase, name: []const u8) !units.Linear {
        if (std.mem.indexOfScalar(u8, name, '^')) |expIndex| {
            const unit = try self.get_unit_or_number(name[0..expIndex]);
            const exponent = try std.fmt.parseInt(i16, name[expIndex + 1 .. name.len], 10);
            return unit.toExponent(exponent);
        } else {
            return self.get_unit_or_number(name);
        }
    }
    fn parse_fraction(self: *UnitDatabase, name: []const u8) !units.Linear {
        if (std.mem.indexOfScalar(u8, name, '/')) |slashIndex| {
            const numerator = try self.parse_exponent(name[0..slashIndex]);
            const denominator = try self.parse_exponent(name[slashIndex + 1 .. name.len]);
            return numerator.dividedBy(denominator);
        } else {
            return self.parse_exponent(name);
        }
    }
    pub fn parse_expression(self: *UnitDatabase, name: []const u8) !units.Linear {
        var product = units.ONE;
        var it = std.mem.splitScalar(u8, name, ' ');
        while (it.next()) |el| {
            if (el.len == 0) continue;

            const unit = try self.parse_fraction(el);
            product = product.times(unit);
        }

        return product;
    }
    fn try_prefix(self: *UnitDatabase, prefixName: []const u8, unitName: []const u8) ?units.Linear {
        const prefix = self.prefixes.get(prefixName) orelse return null;
        const unit = self.units.get(unitName) orelse return null;
        return unit.scaledBy(prefix);
    }
    pub fn free(self: *UnitDatabase) void {
        self.units.deinit();
        self.prefixes.deinit();
    }
};

pub fn new(allocator: std.mem.Allocator) UnitDatabase {
    const units_map = std.StringHashMap(units.Linear).init(allocator);
    const prefixes_map = std.StringHashMap(f64).init(allocator);
    return UnitDatabase{ .units = units_map, .prefixes = prefixes_map };
}
