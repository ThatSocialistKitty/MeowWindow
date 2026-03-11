const std: type = @import("std");
const builtin: type = @import("builtin");
const backends: type = @import("backends.zig");
const vulkan: type = @import("vulkan.zig");
const meowUtilities: type = @import("MeowUtilities");

const Kind: type = enum {
    Toplevel
};

pub const Base: type = struct {
    allocator: std.mem.Allocator,
    title: [*:0]const u8,
    size: [2]i32,
    kind: Kind,
    running: bool
};

const Implementation: type = struct {
    base: Base,
    backendWindow: *backends.Window,
    vulkanContext: *vulkan.Context
};

pub const CreationError: type = error {
    WindowInitializationFailure,
    GraphicsInitializationFailure
};

pub fn create(allocator: std.mem.Allocator,title: []const u8,size: [2]i32,kind: Kind) CreationError!*@This() {
    const window: *Implementation = allocator.create(Implementation) catch unreachable;
    
    window.base.allocator = allocator;
    window.base.title = window.base.allocator.dupeZ(u8,title) catch unreachable;
    window.base.size = size;
    window.base.kind = kind;
    window.base.running = true;
    window.backendWindow = backends.Window.create(&window.base) catch return CreationError.WindowInitializationFailure;
    window.vulkanContext = window.backendWindow.createVulkanContext() catch return CreationError.GraphicsInitializationFailure;
    
    meowUtilities.log.debug("Created window \"{s}\" :3",.{window.base.title});
    
    return @ptrCast(window);
}

pub fn destroy(self: *@This()) void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    window.vulkanContext.destroy();
    window.backendWindow.destroy();
    std.heap.page_allocator.destroy(window);
}

pub fn getRunning(self: *@This()) bool {
    const window: *Implementation = @ptrCast(@alignCast(self));
    return window.base.running;
}

pub fn emitEvents(self: *@This()) void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    window.backendWindow.emitEvents();
}

pub fn renderFrame(self: *@This()) void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    
    window.vulkanContext.renderFrame() catch {
        window.base.running = false;
        return;
    };
}

pub fn getDeltaTime(self: *@This()) f32 {
    const window: *Implementation = @ptrCast(@alignCast(self));
    return window.vulkanContext.getDeltaTime();
}
