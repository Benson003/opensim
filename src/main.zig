const std = @import("std");
const app = @import("./core/app/app.zig");

pub fn main() !void {
    var opensim = std.mem.zeroes(app.OpenSimApp);
    opensim.init();
    defer opensim.clean();
    opensim.run();
}
