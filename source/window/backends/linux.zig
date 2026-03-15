const std: type = @import("std");
const backends: type = @import("../backends.zig");
const waylandImplementation: type = @import("linux/wayland.zig");
const systemMain: type = @import("../main.zig");
const vulkan: type = @import("../vulkan.zig");
const packageMain: type = @import("../../main.zig");

fn isSessionTypeWayland() bool {
    for (std.os.environ) |environmentVariable| {
        const string: []const u8 = std.mem.span(environmentVariable);
        
        if (std.mem.startsWith(u8,string,"XDG_SESSION_TYPE")) {
            const valueStartIndex: usize = std.mem.indexOf(u8,string,"=").?;
            const value: []const u8 = string[valueStartIndex + 1..];
            
            return std.mem.eql(u8,value,"wayland");
        }
    }
    
    return false;
}

pub const window: type = struct {
    pub fn create(base: *systemMain.Window.Base) !*backends.Window {
        if (isSessionTypeWayland()) {
            return try waylandImplementation.window.create(base);
        } else {
            return error.x11NotSupported;
        }
    }
    
    pub fn destroy(self: *backends.Window) void {
        if (isSessionTypeWayland()) {
            waylandImplementation.window.destroy(self);
        }
    }
    
    pub fn createVulkanContext(self: *backends.Window) vulkan.Context.CreationError!*vulkan.Context {
        return try waylandImplementation.window.createVulkanContext(self);
    }
    
    pub fn emitEvents(self: *backends.Window) !void {
        if (isSessionTypeWayland()) {
            return waylandImplementation.window.emitEvents(self);
        }
    }
};
