const std = @import("std");

pub const NUM_DIMENSIONS: isize = 9;

pub const ONE = Linear{ .magnitude = 1.0, .dimension = [_]i16{0} ** NUM_DIMENSIONS };

/// A unit equal to a constant multiple of the base unit.
/// Most units are linear, notable exceptions are Celsius and Fahrenheit.
pub const Linear = struct {
    magnitude: f64,
    dimension: [NUM_DIMENSIONS]i16,
    pub fn scaledBy(self: Linear, multiplier: f64) Linear {
        return Linear{ .magnitude = self.magnitude * multiplier, .dimension = self.dimension };
    }
    pub fn times(self: Linear, other: Linear) Linear {
        var newDimension: [NUM_DIMENSIONS]i16 = undefined;
        for (0..NUM_DIMENSIONS) |i| {
            newDimension[i] = self.dimension[i] + other.dimension[i];
        }
        return Linear{ .magnitude = self.magnitude * other.magnitude, .dimension = newDimension };
    }
    pub fn dividedBy(self: Linear, other: Linear) Linear {
        var newDimension: [NUM_DIMENSIONS]i16 = undefined;
        for (0..NUM_DIMENSIONS) |i| {
            newDimension[i] = self.dimension[i] - other.dimension[i];
        }
        return Linear{ .magnitude = self.magnitude / other.magnitude, .dimension = newDimension };
    }
    pub fn toExponent(self: Linear, exponent: i16) Linear {
        var newDimension: [NUM_DIMENSIONS]i16 = undefined;
        for (0..NUM_DIMENSIONS) |i| {
            newDimension[i] = self.dimension[i] * exponent;
        }
        const newMagnitude: f64 = std.math.pow(f64, self.magnitude, @floatFromInt(exponent));
        return Linear{ .magnitude = newMagnitude, .dimension = newDimension };
    }
};

/// Units could not be converted because they have different dimensions.
pub const IncompatibleDimensions = error.IncompatibleDimensions;

/// Converts a value from the unit `from` to the unit `to`.
pub fn convert(value: f64, from: Linear, to: Linear) !f64 {
    if (!std.mem.eql(i16, &from.dimension, &to.dimension)) {
        return IncompatibleDimensions;
    }

    return value * from.magnitude / to.magnitude;
}
