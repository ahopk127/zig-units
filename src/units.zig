const std = @import("std");

pub const NUM_DIMENSIONS: isize = 9;

/// A unit equal to a constant multiple of the base unit.
/// Most units are linear, notable exceptions are Celsius and Fahrenheit.
pub const Linear = struct {
    magnitude: f64,
    dimension: [NUM_DIMENSIONS]i16,
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
