const std: type = @import("std");
const builtin: type = @import("builtin");
const backends: type = @import("backends.zig");
const vulkan: type = @import("vulkan.zig");
const meowUtilities: type = @import("MeowUtilities");

pub const Window: type = opaque {
    const Kind: type = enum {
        Toplevel
    };
    
    const Events: type = struct {
        pub fn close(window: *Window) void {
            window.close();
        }
        
        pub fn terminate() void {}
        
        pub fn resize() void {}
        
        pub fn maximize() void {}
        
        pub fn minimize() void {}
        
        pub fn fullscreen() void {}
        
        pub fn focus() void {}
        
        pub fn unfocus() void {}
    };
    
    pub const Base: type = struct {
        allocator: std.mem.Allocator,
        title: []const u8,
        size: [2]i32,
        kind: Kind,
        running: bool,
        eventBus: *meowUtilities.miscellaneous.EventBus(Events),
        self: *Window
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
        window.base.title = window.base.allocator.dupe(u8,title) catch unreachable;
        window.base.size = size;
        window.base.kind = kind;
        window.base.running = true;
        window.base.eventBus = .create(window.base.allocator);
        window.base.self = @ptrCast(window);
        window.backendWindow = backends.Window.create(&window.base) catch return CreationError.WindowInitializationFailure;
        window.vulkanContext = window.backendWindow.createVulkanContext() catch return CreationError.GraphicsInitializationFailure;
        
        return @ptrCast(window);
    }
    
    pub fn destroy(self: *@This()) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        
        window.base.allocator.free(window.base.title);
        window.base.eventBus.destroy();
        window.backendWindow.destroy();
        window.vulkanContext.destroy();
        window.base.allocator.destroy(window);
    }
    
    pub fn stepEventLoop(self: *@This()) bool {
        const window: *Implementation = @ptrCast(@alignCast(self));
        
        window.backendWindow.emitEvents() catch unreachable;
        window.vulkanContext.renderFrame() catch unreachable;
        
        return window.base.running;
    }
    
    pub fn close(self: *@This()) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        window.base.running = false;
    }
    
    pub fn getDeltaTime(self: *@This()) f32 {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.vulkanContext.getDeltaTime();
    }
};
