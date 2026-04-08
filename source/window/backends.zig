const builtin: type = @import("builtin");
const linuxBackend: type = @import("backends/linux.zig");
const systemMain: type = @import("main.zig");
const vulkan: type = @import("vulkan.zig");
const packageMain: type = @import("../main.zig");

const selectedBackend: type = switch (builtin.target.os.tag) {
   .linux => linuxBackend,
   else => |target| @compileError("There is no window backend implementation for \"" ++ @tagName(target) ++ "\"")
};

pub const Window: type = opaque {
    pub fn create(base: *systemMain.Window.Base) !*@This() {
        return try selectedBackend.window.create(base);
    }
    
    pub fn destroy(self: *@This()) void {
        selectedBackend.window.destroy(self);
    }
    
    pub fn createGraphicsContext(self: *@This()) vulkan.Context.CreationError!*vulkan.Context {
        return try selectedBackend.window.createGraphicsContext(self);
    }
    
    pub fn emitEvents(self: *@This()) !void {
        return selectedBackend.window.emitEvents(self);
    }
};

pub const Pointer: type = opaque {};

pub const Keyboard: type = opaque {};

pub const Display: type = opaque {};
