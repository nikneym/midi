const std = @import("std");
const os = std.os;
const mem = std.mem;
const midi = @import("main.zig");

pub fn main() !void {
    const fd = try os.open("/dev/midi1", 0, os.O.RDONLY);
    var m = midi.Device.initFd(fd);
    defer m.deinit();

    while (true) {
        const packet = try m.nextPacket();
        std.debug.print("{}\n", .{packet});
    }
}
