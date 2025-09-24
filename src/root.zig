pub const units = @import("units.zig");
pub const db = @import("db.zig");

test "run all lib tests" {
    @import("std").testing.refAllDecls(@This());
}
