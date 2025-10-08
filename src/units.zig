const std = @import("std");

pub const NUM_DIMENSIONS: isize = 9;
pub const ONE = Linear{ .magnitude = 1.0, .dimension = [_]i16{0} ** NUM_DIMENSIONS };
pub const SECOND = base(0);
pub const METRE = base(1);
pub const KILOGRAM = base(2);
pub const RADIAN = base(3);
pub const KELVIN = base(4);
pub const AMPERE = base(5);
pub const MOLE = base(6);
pub const CANDELA = base(7);
pub const BIT = base(8);

fn base(id: usize) Linear {
    var dimension = [_]i16{0} ** NUM_DIMENSIONS;
    dimension[id] = 1;
    return Linear{ .magnitude = 1.0, .dimension = dimension };
}

/// A unit equal to a constant multiple of the base unit.
/// Most units are linear, notable exceptions are Celsius and Fahrenheit.
pub const Linear = struct {
    magnitude: f64,
    dimension: [NUM_DIMENSIONS]i16,
    /// Converts a value from this unit to the base unit.
    pub fn convertToBase(self: Linear, value: f64) f64 {
        return value * self.magnitude;
    }
    /// Converts a value from the base unit to this unit.
    pub fn convertFromBase(self: Linear, value: f64) f64 {
        return value / self.magnitude;
    }
    /// Returns this unit multiplied by a number.
    pub fn scaledBy(self: Linear, multiplier: f64) Linear {
        return Linear{ .magnitude = self.magnitude * multiplier, .dimension = self.dimension };
    }
    /// Returns this unit multiplied by other.
    pub fn times(self: Linear, other: Linear) Linear {
        var newDimension: [NUM_DIMENSIONS]i16 = undefined;
        for (0..NUM_DIMENSIONS) |i| {
            newDimension[i] = self.dimension[i] + other.dimension[i];
        }
        return Linear{ .magnitude = self.magnitude * other.magnitude, .dimension = newDimension };
    }
    /// Returns this unit divided by other.
    pub fn dividedBy(self: Linear, other: Linear) Linear {
        var newDimension: [NUM_DIMENSIONS]i16 = undefined;
        for (0..NUM_DIMENSIONS) |i| {
            newDimension[i] = self.dimension[i] - other.dimension[i];
        }
        return Linear{ .magnitude = self.magnitude / other.magnitude, .dimension = newDimension };
    }
    /// Returns this unit raised to an integer exponent.
    pub fn toExponent(self: Linear, exponent: i16) Linear {
        var newDimension: [NUM_DIMENSIONS]i16 = undefined;
        for (0..NUM_DIMENSIONS) |i| {
            newDimension[i] = self.dimension[i] * exponent;
        }
        const newMagnitude: f64 = std.math.pow(f64, self.magnitude, @floatFromInt(exponent));
        return Linear{ .magnitude = newMagnitude, .dimension = newDimension };
    }
};

pub const Affine = struct {
    magnitude: f64,
    /// The value of zero of this unit in the associated linear unit
    zero: f64,
    dimension: [NUM_DIMENSIONS]i16,
    /// Converts a value from this unit to the base unit.
    pub fn convertToBase(self: Affine, value: f64) f64 {
        return (value + self.zero) * self.magnitude;
    }
    /// Converts a value from the base unit to this unit.
    pub fn convertFromBase(self: Affine, value: f64) f64 {
        return value / self.magnitude - self.zero;
    }
};

pub const Unit = union(enum) {
    linear: Linear,
    affine: Affine,

    pub fn dimension(self: Unit) [NUM_DIMENSIONS]i16 {
        switch (self) {
            inline else => |unit| return unit.dimension,
        }
    }
    pub fn convertFromBase(self: Unit, value: f64) f64 {
        switch (self) {
            inline else => |unit| return unit.convertFromBase(value),
        }
    }
    pub fn convertToBase(self: Unit, value: f64) f64 {
        switch (self) {
            inline else => |unit| return unit.convertToBase(value),
        }
    }
};

/// Units could not be converted because they have different dimensions.
pub const IncompatibleDimensions = error.IncompatibleDimensions;

/// Converts a value from the unit `from` to the unit `to`.
pub fn convert(value: f64, from: Unit, to: Unit) !f64 {
    if (!std.mem.eql(i16, &from.dimension(), &to.dimension())) {
        return IncompatibleDimensions;
    }

    const baseValue = from.convertToBase(value);
    return to.convertFromBase(baseValue);
}

/// Converts a value from the unit `from` to the unit `to`.
pub fn convertLinear(value: f64, from: Linear, to: Linear) !f64 {
    if (!std.mem.eql(i16, &from.dimension, &to.dimension)) {
        return IncompatibleDimensions;
    }

    return value * from.magnitude / to.magnitude;
}

const LENGTH = [3]i16{ 0, 1, 0 } ++ [_]i16{0} ** (NUM_DIMENSIONS - 3);
const VELOCITY = [3]i16{ -1, 1, 0 } ++ [_]i16{0} ** (NUM_DIMENSIONS - 3);
const FORCE = [3]i16{ -2, 1, 1 } ++ [_]i16{0} ** (NUM_DIMENSIONS - 3);
const km = Linear{ .magnitude = 1e3, .dimension = LENGTH };
const kmph = Linear{ .magnitude = 1.0 / 3.6, .dimension = VELOCITY };
const newton = Linear{ .magnitude = 1.0, .dimension = FORCE };
const degC = Affine{ .dimension = KELVIN.dimension, .magnitude = 1.0, .zero = 273.15 };
const degF = Affine{ .dimension = KELVIN.dimension, .magnitude = 1.0 / 1.8, .zero = 459.67 };

test "can convert between metre and km" {
    const metre = Unit{ .linear = METRE };
    const kmUnit = Unit{ .linear = km };
    const result = try convert(12345.0, metre, kmUnit);
    try std.testing.expectApproxEqRel(12.345, result, 1e-15);
}

test "can convert between metre and km (linear)" {
    const result = try convertLinear(12345.0, METRE, km);
    try std.testing.expectApproxEqRel(12.345, result, 1e-15);
}

test "can create km by scaling" {
    const result = METRE.scaledBy(1e3);
    try std.testing.expectEqual(km, result);
}

test "can create km/h" {
    const test_km = METRE.scaledBy(1e3);
    const test_hr = SECOND.scaledBy(3.6e3);
    const test_kmph = test_km.dividedBy(test_hr);
    try std.testing.expectEqual(kmph, test_kmph);
}

test "can create newton using ×, ÷ and ^" {
    const test_N = KILOGRAM.times(METRE).dividedBy(SECOND.toExponent(2));
    try std.testing.expectEqual(newton, test_N);
}

test "can convert temperature" {
    const result = try convert(10.0, Unit{ .affine = degC }, Unit{ .affine = degF });
    try std.testing.expectApproxEqRel(50.0, result, 1e-12);
}
