const std: type = @import("std");
const systemMain: type = @import("../../main.zig");
const backends: type = @import("../../backends.zig");
const meowUtilities: type = @import("MeowUtilities");
const vulkan: type = @import("../../vulkan.zig");
const wayland: type = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("xdg-shell-client-protocol.h");
    @cInclude("xkbcommon/xkbcommon.h");
});
const stdC: type = @cImport({
    @cInclude("sys/mman.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
    @cInclude("poll.h");
});

const PointerImplementation: type = struct {
    waylandPointer: *wayland.wl_pointer,
    waylandListener: wayland.wl_pointer_listener,
    position: @Vector(2,f32)
};

const KeyboardImplementation: type = struct {
    waylandKeyboard: *wayland.wl_keyboard,
    waylandListener: wayland.wl_keyboard_listener,
    xkbKeymap: *wayland.xkb_keymap,
    xkbKeymapState: *wayland.xkb_state
};

pub const window: type = struct {
    const Implementation: type = struct {
        base: *systemMain.Window.Base,
        waylandDisplay: *wayland.wl_display,
        waylandRegistry: *wayland.wl_registry,
        eventError: ?window.EventError,
        waylandRegistryListener: wayland.wl_registry_listener,
        waylandCompositor: ?*wayland.wl_compositor = null,
        xdgWindowManagerBase: ?*wayland.xdg_wm_base = null,
        xdgWindowManagerBaseListener: wayland.xdg_wm_base_listener,
        waylandSeat: ?*wayland.wl_seat = null,
        pointer: PointerImplementation,
        keyboard: KeyboardImplementation,
        waylandSurface: *wayland.wl_surface,
        waylandSurfaceListener: wayland.wl_surface_listener,
        xdgSurface: *wayland.xdg_surface,
        xdgSurfaceListener: wayland.xdg_surface_listener,
        xdgWindow: union {
            toplevel: *wayland.xdg_toplevel
        },
        xdgWindowListener: union {
            toplevel: wayland.xdg_toplevel_listener
        },
        sizeChanged: bool,
        vulkanContext: *vulkan.Context
    };
    
    fn xdgWindowManagerBasePing(data: ?*anyopaque,xdgWindowManagerBase: ?*wayland.xdg_wm_base,serial: u32) callconv(.c) void {
        wayland.xdg_wm_base_pong(xdgWindowManagerBase,serial);
        _ = data;
    }
    
    fn waylandPointerEnter(data: ?*anyopaque,waylandPointer: ?*wayland.wl_pointer,serial: u32,waylandSurface: ?*wayland.wl_surface,waylandSurfaceX: wayland.wl_fixed_t,waylandSurfaceY: wayland.wl_fixed_t) callconv(.c) void {
        _ = data;
        _ = waylandPointer;
        _ = serial;
        _ = waylandSurface;
        _ = waylandSurfaceX;
        _ = waylandSurfaceY;
    }
    
    fn waylandPointerLeave(data: ?*anyopaque,waylandPointer: ?*wayland.wl_pointer,serial: u32,waylandSurface: ?*wayland.wl_surface) callconv(.c) void {
        _ = data;
        _ = waylandPointer;
        _ = serial;
        _ = waylandSurface;
    }
    
    fn waylandPointerMotion(data: ?*anyopaque,waylandPointer: ?*wayland.wl_pointer,time: u32,waylandSurfaceX: wayland.wl_fixed_t,waylandSurfaceY: wayland.wl_fixed_t) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        windowImplementation.pointer.position = .{
            @floatFromInt(wayland.wl_fixed_to_int(waylandSurfaceX)),
            @floatFromInt(wayland.wl_fixed_to_int(waylandSurfaceY))
        };
        
        _ = waylandPointer;
        _ = time;
    }
    
    fn waylandPointerButton(data: ?*anyopaque,waylandPointer: ?*wayland.wl_pointer,serial: u32,time: u32,button: u32,state: u32) callconv(.c) void {
        _ = data;
        _ = waylandPointer;
        _ = serial;
        _ = time;
        _ = button;
        _ = state;
    }
    
    fn waylandKeyboardKeymap(data: ?*anyopaque,waylandKeyboard: ?*wayland.wl_keyboard,format: u32,fileDescriptor: i32,size: u32) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        if (format != wayland.WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1) {
            _ = stdC.close(fileDescriptor);
            return;
        }
        
        const xkbContext: *wayland.xkb_context = wayland.xkb_context_new(wayland.XKB_CONTEXT_NO_FLAGS) orelse {
            windowImplementation.eventError = EventError.ObjectRetrievalFailure;
            return;
        };
        
        const xkbKeymapString: [*:0]const u8 = @ptrCast(stdC.mmap(null,size,stdC.PROT_READ,stdC.MAP_SHARED,fileDescriptor,0).?);
        
        const xkbKeymap: *wayland.xkb_keymap = wayland.xkb_keymap_new_from_string(xkbContext,xkbKeymapString,wayland.XKB_KEYMAP_FORMAT_TEXT_V1,wayland.XKB_KEYMAP_COMPILE_NO_FLAGS) orelse {
            windowImplementation.eventError = EventError.ObjectRetrievalFailure;
            return;
        };
        
        _ = stdC.munmap(@ptrCast(@constCast(xkbKeymapString)),size);
        _ = stdC.close(fileDescriptor);
        
        const xkbKeymapState: *wayland.xkb_state = wayland.xkb_state_new(xkbKeymap) orelse {
            windowImplementation.eventError = EventError.ObjectRetrievalFailure;
            return;
        };
        
        windowImplementation.keyboard.xkbKeymap = xkbKeymap;
        windowImplementation.keyboard.xkbKeymapState = xkbKeymapState;
        
        _ = waylandKeyboard;
    }
    
    fn waylandKeyboardEnter(data: ?*anyopaque,waylandKeyboard: ?*wayland.wl_keyboard,format: u32,waylandSurface: ?*wayland.wl_surface,keys: [*c]wayland.wl_array) callconv(.c) void {
        _ = data;
        _ = waylandKeyboard;
        _ = format;
        _ = waylandSurface;
        _ = keys;
    }
    
    fn waylandKeyboardLeave(data: ?*anyopaque,waylandkeyboard: ?*wayland.wl_keyboard,format: u32,waylandsurface: ?*wayland.wl_surface) callconv(.c) void {
        _ = data;
        _ = waylandkeyboard;
        _ = format;
        _ = waylandsurface;
    }
    
    fn waylandKeyboardKey(data: ?*anyopaque,waylandKeyboard: ?*wayland.wl_keyboard,serial: u32,time: u32,key: u32,state: u32) callconv(.c) void {
        _ = data;
        _ = waylandKeyboard;
        _ = serial;
        _ = time;
        _ = key;
        _ = state;
    }
    
    fn waylandKeyboardModifiers(data: ?*anyopaque,waylandKeyboard: ?*wayland.wl_keyboard,serial: u32,depressedModifiers: u32,latchedModifiers: u32,lockedModifiers: u32,group: u32) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        if (wayland.xkb_state_update_mask(
            windowImplementation.keyboard.xkbKeymapState,
            depressedModifiers,
            latchedModifiers,
            lockedModifiers,
            0,
            0,
            group
        ) == -1) {
            windowImplementation.eventError = EventError.UpdateFailure;
            return;
        }
        
        _ = waylandKeyboard;
        _ = serial;
    }
    
    fn waylandRegistryGlobal(data: ?*anyopaque,waylandRegistry: ?*wayland.wl_registry,name: u32,interface: [*c]const u8,version: u32) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        if (std.mem.eql(u8,std.mem.span(interface),"wl_compositor")) {
            windowImplementation.waylandCompositor = @ptrCast(wayland.wl_registry_bind(waylandRegistry,name,&wayland.wl_compositor_interface,4) orelse {
                windowImplementation.eventError = EventError.ObjectRetrievalFailure;
                return;
            });
        }
        
        if (std.mem.eql(u8,std.mem.span(interface),"xdg_wm_base")) {
            windowImplementation.xdgWindowManagerBase = @ptrCast(wayland.wl_registry_bind(waylandRegistry,name,&wayland.xdg_wm_base_interface,1) orelse {
                windowImplementation.eventError = EventError.ObjectRetrievalFailure;
                return;
            });
            
            windowImplementation.xdgWindowManagerBaseListener = wayland.xdg_wm_base_listener {
                .ping = xdgWindowManagerBasePing
            };
            
            if (wayland.xdg_wm_base_add_listener(windowImplementation.xdgWindowManagerBase,&windowImplementation.xdgWindowManagerBaseListener,windowImplementation) == -1) {
                windowImplementation.eventError = EventError.AddListenerFailure;
                return;
            }
        }
        
        if (std.mem.eql(u8,std.mem.span(interface),"wl_seat")) {
            windowImplementation.waylandSeat = @ptrCast(wayland.wl_registry_bind(waylandRegistry,name,&wayland.wl_seat_interface,1) orelse {
                windowImplementation.eventError = EventError.ObjectRetrievalFailure;
                return;
            });
            
            windowImplementation.pointer.waylandPointer = wayland.wl_seat_get_pointer(windowImplementation.waylandSeat) orelse {
                windowImplementation.eventError = EventError.ObjectRetrievalFailure;
                return;
            };
            
            windowImplementation.pointer.waylandListener = wayland.wl_pointer_listener {
                .enter = waylandPointerEnter,
                .leave = waylandPointerLeave,
                .motion = waylandPointerMotion,
                .button = waylandPointerButton,
                .axis = null,
                .frame = null,
                .axis_source = null,
                .axis_stop = null,
                .axis_discrete = null,
                .axis_relative_direction = null,
                .axis_value120 = null
            };
            
            if (wayland.wl_pointer_add_listener(windowImplementation.pointer.waylandPointer,&windowImplementation.pointer.waylandListener,windowImplementation) == -1) {
                windowImplementation.eventError = EventError.AddListenerFailure;
                return;
            }
            
            windowImplementation.keyboard.waylandKeyboard = wayland.wl_seat_get_keyboard(windowImplementation.waylandSeat) orelse {
                windowImplementation.eventError = EventError.ObjectRetrievalFailure;
                return;
            };
            
            windowImplementation.keyboard.waylandListener = wayland.wl_keyboard_listener {
                .keymap = waylandKeyboardKeymap,
                .enter = waylandKeyboardEnter,
                .leave = waylandKeyboardLeave,
                .key = waylandKeyboardKey,
                .modifiers = waylandKeyboardModifiers,
                .repeat_info = null
            };
            
            if (wayland.wl_keyboard_add_listener(windowImplementation.keyboard.waylandKeyboard,&windowImplementation.keyboard.waylandListener,windowImplementation) == -1) {
                windowImplementation.eventError = EventError.AddListenerFailure;
                return;
            }
        }
        
        _ = version;
    }
    
    fn xdgSurfaceConfigure(data: ?*anyopaque,xdgSurface: ?*wayland.xdg_surface,serial: u32) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        wayland.xdg_surface_ack_configure(xdgSurface,serial);
        
        if (windowImplementation.sizeChanged) {
            windowImplementation.vulkanContext.createSwapchain(windowImplementation.base.size) catch {
                windowImplementation.eventError = EventError.AddListenerFailure;
                return;
            };
            
            windowImplementation.sizeChanged = false;
        }
    }
    
    fn xdgWindowToplevelClose(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        windowImplementation.base.eventBus.append(.{
            .data = .{
                .close = .{
                    .window = windowImplementation.base.self
                }
            }
        });
        
        _ = xdgToplevel;
    }
    
    fn xdgWindowToplevelConfigure(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel,width: i32,height: i32,states: ?*wayland.wl_array) callconv(.c) void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(data));
        
        if (width > 0 and height > 0 and (width != windowImplementation.base.size[0] or height != windowImplementation.base.size[1])) {
            windowImplementation.base.size = .{
                width,
                height
            };
            
            windowImplementation.sizeChanged = true;
        }
        
        _ = xdgToplevel;
        _ = states;
    }
    
    const CreationError: type = error {
        ObjectRetrievalFailure,
        AddListenerFailure,
        DispatchFailure,
        MissingGlobals,
        EventError
    };
    
    const EventError: type = error {
        ObjectRetrievalFailure,
        AddListenerFailure,
        UpdateFailure
    };
    
    pub fn create(base: *systemMain.Window.Base) CreationError!*backends.Window {
        const windowImplementation: *Implementation = base.allocator.create(Implementation) catch unreachable;
        
        errdefer destroy(@ptrCast(windowImplementation));
        
        windowImplementation.base = base;
        
        windowImplementation.waylandDisplay = wayland.wl_display_connect(null) orelse return CreationError.ObjectRetrievalFailure;
        
        windowImplementation.waylandRegistry = wayland.wl_display_get_registry(windowImplementation.waylandDisplay) orelse return CreationError.ObjectRetrievalFailure;
        
        windowImplementation.eventError = null;
        
        windowImplementation.waylandRegistryListener = wayland.wl_registry_listener {
            .global = waylandRegistryGlobal
        };
        
        if (wayland.wl_registry_add_listener(windowImplementation.waylandRegistry,&windowImplementation.waylandRegistryListener,windowImplementation) == -1) return CreationError.AddListenerFailure;
        
        if (wayland.wl_display_roundtrip(windowImplementation.waylandDisplay) == -1) return CreationError.DispatchFailure;
        
        if (windowImplementation.waylandCompositor == null or windowImplementation.xdgWindowManagerBase == null or windowImplementation.waylandSeat == null) {
            return CreationError.MissingGlobals;
        }
        
        windowImplementation.waylandSurface = wayland.wl_compositor_create_surface(windowImplementation.waylandCompositor) orelse return CreationError.ObjectRetrievalFailure;
        
        windowImplementation.waylandSurfaceListener = wayland.wl_surface_listener {
            .enter = null,
            .leave = null,
            .preferred_buffer_scale = null,
            .preferred_buffer_transform = null
        };
        
        if (wayland.wl_surface_add_listener(windowImplementation.waylandSurface,&windowImplementation.waylandSurfaceListener,windowImplementation) == -1) return CreationError.AddListenerFailure;
        
        windowImplementation.xdgSurface = wayland.xdg_wm_base_get_xdg_surface(windowImplementation.xdgWindowManagerBase,windowImplementation.waylandSurface) orelse return CreationError.ObjectRetrievalFailure;
        
        windowImplementation.xdgSurfaceListener = wayland.xdg_surface_listener {
            .configure = xdgSurfaceConfigure
        };
        
        if (wayland.xdg_surface_add_listener(windowImplementation.xdgSurface,&windowImplementation.xdgSurfaceListener,windowImplementation) == -1) return CreationError.AddListenerFailure;
        
        switch (windowImplementation.base.kind) {
            .Toplevel => {
                windowImplementation.xdgWindow.toplevel = wayland.xdg_surface_get_toplevel(windowImplementation.xdgSurface) orelse return CreationError.ObjectRetrievalFailure;
                
                windowImplementation.xdgWindowListener.toplevel = wayland.xdg_toplevel_listener {
                    .close = xdgWindowToplevelClose,
                    .configure = xdgWindowToplevelConfigure,
                    .configure_bounds = null,
                    .wm_capabilities = null
                };
                
                if (wayland.xdg_toplevel_add_listener(windowImplementation.xdgWindow.toplevel,&windowImplementation.xdgWindowListener.toplevel,windowImplementation) == -1) return CreationError.AddListenerFailure;
                
                wayland.xdg_toplevel_set_title(windowImplementation.xdgWindow.toplevel,windowImplementation.base.title.ptr);
            }
        }
        
        wayland.xdg_surface_set_window_geometry(windowImplementation.xdgSurface,0,0,windowImplementation.base.size[0],windowImplementation.base.size[1]);
        
        wayland.wl_surface_commit(windowImplementation.waylandSurface);
        
        return @ptrCast(windowImplementation);
    }
   
    // TODO: Plagerize
pub fn destroy(self: *backends.Window) void {
    const windowImpl: *Implementation = @ptrCast(@alignCast(self));

    // Destroy XDG Toplevel
    wayland.xdg_toplevel_destroy(windowImpl.xdgWindow.toplevel);

    // Destroy XDG Surface
    wayland.xdg_surface_destroy(windowImpl.xdgSurface);

    // Destroy Wayland Surface
    wayland.wl_surface_destroy(windowImpl.waylandSurface);

    // Destroy XDG Window Manager Base
    wayland.xdg_wm_base_destroy(windowImpl.xdgWindowManagerBase);

    // Destroy Wayland Seat
    wayland.wl_seat_destroy(windowImpl.waylandSeat);

    // Destroy Registry
    wayland.wl_registry_destroy(windowImpl.waylandRegistry);

    // Disconnect Display
    wayland.wl_display_disconnect(windowImpl.waylandDisplay);

    // Free memory
    windowImpl.base.allocator.destroy(windowImpl);
}    
    pub fn createVulkanContext(self: *backends.Window) vulkan.Context.CreationError!*vulkan.Context {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(self));
        const context: *vulkan.Context = try vulkan.Context.create(
            windowImplementation.base.allocator,
            @ptrCast(@constCast(&vulkan.Context.WaylandWindowHandles {
                .display = @ptrCast(windowImplementation.waylandDisplay),
                .surface = @ptrCast(windowImplementation.waylandSurface)
            })),
            .Wayland,
            windowImplementation.base.size
        );
        
        windowImplementation.vulkanContext = context;
        
        return context;
    }
    
    // TODO: Plagiarize
    
    pub fn emitEvents(self: *backends.Window) EventError!void {
        const windowImplementation: *Implementation = @ptrCast(@alignCast(self));
        
        // Step 1: dispatch any pending events first
        _ = wayland.wl_display_dispatch_pending(windowImplementation.waylandDisplay);
        
        // Step 2: prepare for reading new events
        if (wayland.wl_display_prepare_read(windowImplementation.waylandDisplay) < 0) {
            // nothing ready to read, flush if necessary
            _ = wayland.wl_display_flush(windowImplementation.waylandDisplay);
            return;
        }
        
        const fd: i32 = wayland.wl_display_get_fd(windowImplementation.waylandDisplay);
        var pfd: stdC.pollfd = .{
            .fd = fd,
            .events = stdC.POLLIN,
        };
        
        // Non-blocking poll (timeout = 0)
        const n = stdC.poll(@ptrCast(&pfd), 1, 0);
        
        if (n > 0 and (pfd.revents & stdC.POLLIN != 0)) {
            // fd is ready for reading
            if (wayland.wl_display_read_events(windowImplementation.waylandDisplay) == -1) {
                wayland.wl_display_cancel_read(windowImplementation.waylandDisplay);
                return;
            }
            _ = wayland.wl_display_dispatch_pending(windowImplementation.waylandDisplay);
        } else {
            // nothing to read right now
            wayland.wl_display_cancel_read(windowImplementation.waylandDisplay);
        }
        
        if (windowImplementation.eventError != null) {
            return windowImplementation.eventError.?;
        }
    }
};
