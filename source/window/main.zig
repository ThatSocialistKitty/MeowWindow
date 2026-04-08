const std: type = @import("std");
const builtin: type = @import("builtin");
const backends: type = @import("backends.zig");
const vulkan: type = @import("vulkan.zig");
const meowUtilities: type = @import("MeowUtilities");

pub const Window: type = opaque {
    const Kind: type = enum {
        Toplevel
    };
    
    // TODO: Create da other events meow :3
    
    const EventBus: type = meowUtilities.miscellaneous.EventBus(union(enum) {
        close: struct {
            window: *Window
        },
        // terminate: ,
        // resize: ,
        // maximize: ,
        // minimize: ,
        // fullscreen: ,
        // focus: ,
        // unfocus: 
    });
    
    pub const Base: type = struct {
        allocator: std.mem.Allocator,
        title: []const u8,
        size: [2]i32,
        kind: Kind,
        running: bool,
        eventBus: *EventBus,
        eventBusDefaultConsumer: *EventBus.Consumer,
        eventBusRegularConsumer: *EventBus.Consumer,
        self: *Window
    };
    
    const Implementation: type = struct {
        base: Base,
        backendWindow: *backends.Window,
        graphicsContext: *vulkan.Context
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
        window.base.eventBusDefaultConsumer = window.base.eventBus.createConsumer();
        window.base.eventBusRegularConsumer = window.base.eventBus.createConsumer();
        window.base.self = @ptrCast(window);
        window.backendWindow = backends.Window.create(&window.base) catch return CreationError.WindowInitializationFailure;
        window.graphicsContext = window.backendWindow.createGraphicsContext() catch return CreationError.GraphicsInitializationFailure;
        
        return @ptrCast(window);
    }
    
    pub fn destroy(self: *@This()) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        
        window.base.allocator.free(window.base.title);
        window.base.eventBus.destroy();
        window.backendWindow.destroy();
        window.graphicsContext.destroy();
        
        window.base.allocator.destroy(window);
    }
    
    pub fn stepEventLoop(self: *@This()) bool {
        const window: *Implementation = @ptrCast(@alignCast(self));
        
        while (window.base.eventBusDefaultConsumer.poll()) |event| {
            if (!event.*.preventDefault) {
                switch (event.*.data) {
                    .close => |data| data.window.close()
                }
            }
        }
        
        window.backendWindow.emitEvents() catch unreachable;
        window.graphicsContext.renderFrame() catch unreachable;
        
        return window.base.running;
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.base.eventBusRegularConsumer.poll();
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
