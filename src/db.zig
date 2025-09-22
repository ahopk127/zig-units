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

        return UnitNotFound;
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
