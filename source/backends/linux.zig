const std: type = @import("std");
const waylandImplementation: type = @import("linux/wayland.zig");
const moduleMain: type = @import("../main.zig");

fn isSessionTypeWayland() bool {
    for (std.os.environ) |environmentVariable| {
        const sessionType: []const u8 = std.mem.span(environmentVariable);
        
        if (std.mem.startsWith(u8,sessionType,"XDG_SESSION_TYPE")) {
            return std.mem.eql(u8,sessionType[std.mem.indexOf(u8,sessionType,"=").? + 1..],"wayland");
        }
    }
    
    return false;
}

pub fn create(base: *moduleMain.Window.Base) !*@This() {
    if (isSessionTypeWayland()) {
        return try waylandImplementation.create(base);
    } else {
        return error.x11NotSupported;
    }
}

pub fn destroy(self: *@This()) void {
    if (isSessionTypeWayland()) {
        waylandImplementation.destroy(self);
    }
}

pub fn getRawHandles(self: *@This()) moduleMain.Window.RawHandles {
    if (isSessionTypeWayland() or true) {
        return waylandImplementation.getRawHandles(self);
    }
}

pub fn stepMainLoop(self: *@This()) !void {
    if (isSessionTypeWayland()) {
        return waylandImplementation.stepMainLoop(self);
    }
}

pub fn setFullscreen(self: *@This(),state: bool) void {
    if (isSessionTypeWayland()) {
        waylandImplementation.setFullscreen(self,state);
    }
}

pub fn setCursor(self: *@This(),cursor: moduleMain.Pointer.Cursor) !void {
    if (isSessionTypeWayland()) {
        try waylandImplementation.setCursor(self,cursor);
    }
}
