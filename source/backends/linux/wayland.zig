const std: type = @import("std");
const moduleMain: type = @import("../../main.zig");
const LinuxBackend: type = @import("../linux.zig");
const meowUtilities: type = @import("MeowUtilities");
const wayland: type = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-cursor.h");
    @cInclude("xdg-shell-client-protocol.h");
    @cInclude("xkbcommon/xkbcommon.h");
});
const stdC: type = @cImport({
    @cInclude("sys/mman.h");
    @cInclude("unistd.h");
    @cInclude("errno.h");
    @cInclude("poll.h");
});
const linux: type = @cImport({
    @cInclude("linux/input.h");
});

const Implementation: type = struct {
    base: *moduleMain.Window.Base,
    display: *wayland.wl_display,
    registry: *wayland.wl_registry,
    eventError: ?anyerror,
    registryListener: wayland.wl_registry_listener,
    compositor: ?*wayland.wl_compositor,
    xdgWindowManagerBase: ?*wayland.xdg_wm_base,
    xdgWindowManagerBaseListener: wayland.xdg_wm_base_listener,
    seat: ?*wayland.wl_seat,
    keyboard: struct {
        keyboard: *wayland.wl_keyboard,
        listener: wayland.wl_keyboard_listener,
        xkbKeymap: *wayland.xkb_keymap,
        xkbKeymapState: *wayland.xkb_state,
        pressUnicode: [8]u8,
        repeatRate: u32,
        repeatDelay: u32,
        repeatingUnicode: [8]u8,
        repeatingEvent: ?moduleMain.Keyboard.KeyEvent,
        repeatTimestamp: meowUtilities.time.Timestamp
    },
    pointer: struct {
        pointer: *wayland.wl_pointer,
        listener: wayland.wl_pointer_listener,
        surface: *wayland.wl_surface,
        theme: *wayland.wl_cursor_theme,
        cursor: ?*wayland.wl_cursor,
        imageIndex: u32,
        updateTimestamp: meowUtilities.time.Timestamp,
        enterSerial: u32
    },
    sharedMemoryBuffer: ?*wayland.wl_shm,
    surface: *wayland.wl_surface,
    xdgSurface: *wayland.xdg_surface,
    xdgSurfaceListener: wayland.xdg_surface_listener,
    xdgWindow: union(enum) {
        toplevel: *wayland.xdg_toplevel
    },
    xdgWindowListener: union {
        toplevel: wayland.xdg_toplevel_listener
    },
    sizeChanged: bool
};

fn xdgWindowManagerBasePing(data: ?*anyopaque,xdgWindowManagerBase: ?*wayland.xdg_wm_base,serial: u32) callconv(.c) void {
    wayland.xdg_wm_base_pong(xdgWindowManagerBase,serial);
    _ = data;
}

fn keyboardKeymap(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,format: u32,fileDescriptor: i32,size: u32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    if (format != wayland.WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1) {
        _ = stdC.close(fileDescriptor);
        return;
    }
    
    const xkbContext: *wayland.xkb_context = wayland.xkb_context_new(wayland.XKB_CONTEXT_NO_FLAGS) orelse {
        window.eventError = error.FailedToCreateXkbContext;
        return;
    };
    
    const xkbKeymapString: [*:0]const u8 = @ptrCast(stdC.mmap(null,size,stdC.PROT_READ,stdC.MAP_SHARED,fileDescriptor,0).?);
    
    const xkbKeymap: *wayland.xkb_keymap = wayland.xkb_keymap_new_from_string(xkbContext,xkbKeymapString,wayland.XKB_KEYMAP_FORMAT_TEXT_V1,wayland.XKB_KEYMAP_COMPILE_NO_FLAGS) orelse {
        window.eventError = error.FailedToCreateXkbKeymap;
        return;
    };
    
    _ = stdC.munmap(@ptrCast(@constCast(xkbKeymapString)),size);
    _ = stdC.close(fileDescriptor);
    
    const xkbKeymapState: *wayland.xkb_state = wayland.xkb_state_new(xkbKeymap) orelse {
        window.eventError = error.FailedToCreateXkbState;
        return;
    };
    
    window.keyboard.xkbKeymap = xkbKeymap;
    window.keyboard.xkbKeymapState = xkbKeymapState;
    
    _ = keyboard;
}

fn keyboardEnter(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,format: u32,surface: ?*wayland.wl_surface,keys: [*c]wayland.wl_array) callconv(.c) void {
    _ = data;
    _ = keyboard;
    _ = format;
    _ = surface;
    _ = keys;
}

fn keyboardLeave(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,format: u32,surface: ?*wayland.wl_surface) callconv(.c) void {
    _ = data;
    _ = keyboard;
    _ = format;
    _ = surface;
}

fn keyboardKey(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,serial: u32,time: u32,key: u32,state: u32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    const keycode: wayland.xkb_keycode_t = key + 8;
        
    _ = wayland.xkb_state_update_key(window.keyboard.xkbKeymapState,keycode,wayland.XKB_KEY_DOWN);
    
    const keyCharacterLength: c_int = wayland.xkb_state_key_get_utf8(window.keyboard.xkbKeymapState,keycode,&window.keyboard.pressUnicode,window.keyboard.pressUnicode.len);
    
    const eventData: moduleMain.Keyboard.KeyEvent = .{
        .key = switch (wayland.xkb_state_key_get_one_sym(window.keyboard.xkbKeymapState,keycode)) {
            wayland.XKB_KEY_A => .A,
            wayland.XKB_KEY_B => .B,
            wayland.XKB_KEY_C => .C,
            wayland.XKB_KEY_D => .D,
            wayland.XKB_KEY_E => .E,
            wayland.XKB_KEY_F => .F,
            wayland.XKB_KEY_G => .G,
            wayland.XKB_KEY_H => .H,
            wayland.XKB_KEY_I => .I,
            wayland.XKB_KEY_J => .J,
            wayland.XKB_KEY_K => .K,
            wayland.XKB_KEY_L => .L,
            wayland.XKB_KEY_M => .M,
            wayland.XKB_KEY_N => .N,
            wayland.XKB_KEY_O => .O,
            wayland.XKB_KEY_P => .P,
            wayland.XKB_KEY_Q => .Q,
            wayland.XKB_KEY_R => .R,
            wayland.XKB_KEY_S => .S,
            wayland.XKB_KEY_T => .T,
            wayland.XKB_KEY_U => .U,
            wayland.XKB_KEY_V => .V,
            wayland.XKB_KEY_W => .W,
            wayland.XKB_KEY_X => .X,
            wayland.XKB_KEY_Y => .Y,
            wayland.XKB_KEY_Z => .Z,
            wayland.XKB_KEY_a => .a,
            wayland.XKB_KEY_b => .b,
            wayland.XKB_KEY_c => .c,
            wayland.XKB_KEY_d => .d,
            wayland.XKB_KEY_e => .e,
            wayland.XKB_KEY_f => .f,
            wayland.XKB_KEY_g => .g,
            wayland.XKB_KEY_h => .h,
            wayland.XKB_KEY_i => .i,
            wayland.XKB_KEY_j => .j,
            wayland.XKB_KEY_k => .k,
            wayland.XKB_KEY_l => .l,
            wayland.XKB_KEY_m => .m,
            wayland.XKB_KEY_n => .n,
            wayland.XKB_KEY_o => .o,
            wayland.XKB_KEY_p => .p,
            wayland.XKB_KEY_q => .q,
            wayland.XKB_KEY_r => .r,
            wayland.XKB_KEY_s => .s,
            wayland.XKB_KEY_t => .t,
            wayland.XKB_KEY_u => .u,
            wayland.XKB_KEY_v => .v,
            wayland.XKB_KEY_w => .w,
            wayland.XKB_KEY_x => .x,
            wayland.XKB_KEY_y => .y,
            wayland.XKB_KEY_z => .z,
            wayland.XKB_KEY_0 => .Zero,
            wayland.XKB_KEY_1 => .One,
            wayland.XKB_KEY_2 => .Two,
            wayland.XKB_KEY_3 => .Three,
            wayland.XKB_KEY_4 => .Four,
            wayland.XKB_KEY_5 => .Five,
            wayland.XKB_KEY_6 => .Six,
            wayland.XKB_KEY_7 => .Seven,
            wayland.XKB_KEY_8 => .Eight,
            wayland.XKB_KEY_9 => .Nine,
            wayland.XKB_KEY_F1 => .F1,
            wayland.XKB_KEY_F2 => .F2,
            wayland.XKB_KEY_F3 => .F3,
            wayland.XKB_KEY_F4 => .F4,
            wayland.XKB_KEY_F5 => .F5,
            wayland.XKB_KEY_F6 => .F6,
            wayland.XKB_KEY_F7 => .F7,
            wayland.XKB_KEY_F8 => .F8,
            wayland.XKB_KEY_F9 => .F9,
            wayland.XKB_KEY_F10 => .F10,
            wayland.XKB_KEY_F11 => .F11,
            wayland.XKB_KEY_F12 => .F12,
            wayland.XKB_KEY_F13 => .F13,
            wayland.XKB_KEY_F14 => .F14,
            wayland.XKB_KEY_F15 => .F15,
            wayland.XKB_KEY_F16 => .F16,
            wayland.XKB_KEY_F17 => .F17,
            wayland.XKB_KEY_F18 => .F18,
            wayland.XKB_KEY_F19 => .F19,
            wayland.XKB_KEY_F20 => .F20,
            wayland.XKB_KEY_F21 => .F21,
            wayland.XKB_KEY_F22 => .F22,
            wayland.XKB_KEY_F23 => .F23,
            wayland.XKB_KEY_F24 => .F24,
            wayland.XKB_KEY_Escape => .Escape,
            wayland.XKB_KEY_Return => .Enter,
            wayland.XKB_KEY_Tab => .Tab,
            wayland.XKB_KEY_space => .Space,
            wayland.XKB_KEY_BackSpace => .Backspace,
            wayland.XKB_KEY_Delete => .Delete,
            wayland.XKB_KEY_Insert => .Insert,
            wayland.XKB_KEY_Shift_L => .LeftShift,
            wayland.XKB_KEY_Shift_R => .RightShift,
            wayland.XKB_KEY_Control_L => .LeftControl,
            wayland.XKB_KEY_Control_R => .RightControl,
            wayland.XKB_KEY_Alt_L => .LeftAlt,
            wayland.XKB_KEY_Alt_R => .RightAlt,
            wayland.XKB_KEY_Super_L => .LeftSuper,
            wayland.XKB_KEY_Super_R => .RightSuper,
            wayland.XKB_KEY_Menu => .Menu,
            wayland.XKB_KEY_Up => .Up,
            wayland.XKB_KEY_Down => .Down,
            wayland.XKB_KEY_Left => .Left,
            wayland.XKB_KEY_Right => .Right,
            wayland.XKB_KEY_Home => .Home,
            wayland.XKB_KEY_End => .End,
            wayland.XKB_KEY_Page_Up => .PageUp,
            wayland.XKB_KEY_Page_Down => .PageDown,
            wayland.XKB_KEY_grave => .GraveAccent,
            wayland.XKB_KEY_asciitilde => .Tilde,
            wayland.XKB_KEY_minus => .Minus,
            wayland.XKB_KEY_equal => .Equals,
            wayland.XKB_KEY_bracketleft => .LeftBracket,
            wayland.XKB_KEY_bracketright => .RightBracket,
            wayland.XKB_KEY_backslash => .Backslash,
            wayland.XKB_KEY_bar => .Pipe,
            wayland.XKB_KEY_semicolon => .Semicolon,
            wayland.XKB_KEY_apostrophe => .Apostrophe,
            wayland.XKB_KEY_comma => .Comma,
            wayland.XKB_KEY_period => .Period,
            wayland.XKB_KEY_slash => .Slash,
            wayland.XKB_KEY_KP_0 => .NumpadZero,
            wayland.XKB_KEY_KP_1 => .NumpadOne,
            wayland.XKB_KEY_KP_2 => .NumpadTwo,
            wayland.XKB_KEY_KP_3 => .NumpadThree,
            wayland.XKB_KEY_KP_4 => .NumpadFour,
            wayland.XKB_KEY_KP_5 => .NumpadFive,
            wayland.XKB_KEY_KP_6 => .NumpadSix,
            wayland.XKB_KEY_KP_7 => .NumpadSeven,
            wayland.XKB_KEY_KP_8 => .NumpadEight,
            wayland.XKB_KEY_KP_9 => .NumpadNine,
            wayland.XKB_KEY_KP_Decimal => .NumpadDecimal,
            wayland.XKB_KEY_KP_Divide => .NumpadDivide,
            wayland.XKB_KEY_KP_Multiply => .NumpadMultiply,
            wayland.XKB_KEY_KP_Subtract => .NumpadSubtract,
            wayland.XKB_KEY_KP_Add => .NumpadAdd,
            wayland.XKB_KEY_KP_Enter => .NumpadEnter,
            wayland.XKB_KEY_KP_Equal => .NumpadEquals,
            wayland.XKB_KEY_XF86AudioPlay => .MediaPlay,
            wayland.XKB_KEY_XF86AudioPause => .MediaPause,
            wayland.XKB_KEY_XF86AudioStop => .MediaStop,
            wayland.XKB_KEY_XF86AudioNext => .MediaNextTrack,
            wayland.XKB_KEY_XF86AudioPrev => .MediaPreviousTrack,
            wayland.XKB_KEY_XF86AudioRaiseVolume => .VolumeUp,
            wayland.XKB_KEY_XF86AudioLowerVolume => .VolumeDown,
            wayland.XKB_KEY_XF86AudioMute => .Mute,
            else => .Unknown
        },
        .unicode = if (keyCharacterLength > 0) window.keyboard.pressUnicode[0..@intCast(keyCharacterLength)] else null,
        .timestamp = meowUtilities.time.getUniversalTimestamp()
    };
    
    switch (state) {
        wayland.WL_KEYBOARD_KEY_STATE_PRESSED => {
            if (wayland.xkb_keymap_key_repeats(window.keyboard.xkbKeymap,keycode) == 1) {
                if (window.keyboard.repeatingEvent != null) {
                    window.keyboard.repeatingEvent = null;
                }
                
                if (eventData.unicode != null) {
                    @memcpy(&window.keyboard.repeatingUnicode,eventData.unicode.?.ptr);
                }
                
                window.keyboard.repeatingEvent = .{
                    .key = eventData.key,
                    .unicode = if (eventData.unicode != null) window.keyboard.repeatingUnicode[0..eventData.unicode.?.len] else null,
                    .timestamp = eventData.timestamp
                };
                
                window.keyboard.repeatTimestamp = meowUtilities.time.getUniversalTimestamp() + @as(meowUtilities.time.Timestamp,window.keyboard.repeatDelay) * std.time.us_per_ms;
            }
            
            window.base.keyboardEventBus.append(.{
                .press = eventData
            });
        },
        wayland.WL_KEYBOARD_KEY_STATE_RELEASED => {
            if (window.keyboard.repeatingEvent != null) {
                if (window.keyboard.repeatingEvent.?.key == eventData.key) {
                    window.keyboard.repeatingEvent = null;
                }
            }
            
            window.base.keyboardEventBus.append(.{
                .release = eventData
            });
        },
        else => return
    }
    
    _ = keyboard;
    _ = serial;
    _ = time;
}

fn keyboardModifiers(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,serial: u32,depressedModifiers: u32,latchedModifiers: u32,lockedModifiers: u32,group: u32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    if (wayland.xkb_state_update_mask(window.keyboard.xkbKeymapState,depressedModifiers,latchedModifiers,lockedModifiers,0,0,group) == -1) {
        window.eventError = error.FailedToUpdateXkbMask;
        return;
    }
    
    _ = keyboard;
    _ = serial;
}

fn keyboardRepeatInformation(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,rate: i32,delay: i32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    window.keyboard.repeatRate = @intCast(rate);
    window.keyboard.repeatDelay = @intCast(delay);
    
    _ = keyboard;
}

fn pointerEnter(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,serial: u32,surface: ?*wayland.wl_surface,surfaceX: wayland.wl_fixed_t,surfaceY: wayland.wl_fixed_t) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    window.pointer.enterSerial = serial;
    
    _ = pointer;
    _ = surface;
    _ = surfaceX;
    _ = surfaceY;
}

fn pointerLeave(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,serial: u32,surface: ?*wayland.wl_surface) callconv(.c) void {
    _ = data;
    _ = pointer;
    _ = serial;
    _ = surface;
}

fn pointerMotion(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,time: u32,surfaceX: wayland.wl_fixed_t,surfaceY: wayland.wl_fixed_t) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    window.base.pointerEventBus.append(.{
        .move = .{
            .position = .{
                @floatFromInt(wayland.wl_fixed_to_int(surfaceX)),
                @floatFromInt(wayland.wl_fixed_to_int(surfaceY))
            },
            .timestamp = meowUtilities.time.getUniversalTimestamp()
        }
    });
    
    _ = pointer;
    _ = time;
}

fn pointerButton(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,serial: u32,time: u32,button: u32,state: u32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    const eventData: moduleMain.Pointer.ButtonEvent = .{
        .button = switch (button) {
            linux.BTN_LEFT => .Left,
            linux.BTN_RIGHT => .Right,
            linux.BTN_MIDDLE => .Middle,
            linux.BTN_EXTRA => .Next,
            linux.BTN_SIDE => .Previous,
            else => .Unknown
        },
        .timestamp = meowUtilities.time.getUniversalTimestamp()
    };
    
    switch (state) {
        wayland.WL_POINTER_BUTTON_STATE_PRESSED => {
            window.base.pointerEventBus.append(.{
                .press = eventData
            });
        },
        wayland.WL_POINTER_BUTTON_STATE_RELEASED => {
            window.base.pointerEventBus.append(.{
                .release = eventData
            });
        },
        else => return
    }
    
    _ = pointer;
    _ = serial;
    _ = time;
}

fn pointerAxis(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,time: u32,axis: u32,value: wayland.wl_fixed_t) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    window.base.pointerEventBus.append(.{
        .scroll = .{
            .direction = if (wayland.wl_fixed_to_int(value) > 0) .Down else .Up,
            .timestamp = meowUtilities.time.getUniversalTimestamp()
        }
    });
    
    _ = pointer;
    _ = time;
    _ = axis;
}

fn pointerFrame(data: ?*anyopaque,pointer: ?*wayland.wl_pointer) callconv(.c) void {
    _ = data;
    _ = pointer;
}

fn pointerAxisSource(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,source: u32) callconv(.c) void {
    _ = data;
    _ = pointer;
    _ = source;
}

fn pointerAxisStop(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,time: u32,axis: u32) callconv(.c) void {
    _ = data;
    _ = pointer;
    _ = time;
    _ = axis;
}

fn pointerAxisDescrete(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,axis: u32,discrete: i32) callconv(.c) void {
    _ = data;
    _ = pointer;
    _ = axis;
    _ = discrete;
}

fn pointerAxisRelativeDirection(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,axis: u32,direction: u32) callconv(.c) void {
    _ = data;
    _ = pointer;
    _ = axis;
    _ = direction;
}

fn pointerAxisValue120(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,axis: u32,value120: i32) callconv(.c) void {
    _ = data;
    _ = pointer;
    _ = axis;
    _ = value120;
}

fn registryGlobal(data: ?*anyopaque,registry: ?*wayland.wl_registry,name: u32,interface: [*c]const u8,version: u32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    if (std.mem.eql(u8,std.mem.span(interface),"wl_compositor")) {
        window.compositor = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.wl_compositor_interface,version) orelse {
            window.eventError = error.FailedToBindCompositor;
            return;
        });
    }
    
    if (std.mem.eql(u8,std.mem.span(interface),"xdg_wm_base")) {
        window.xdgWindowManagerBase = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.xdg_wm_base_interface,version) orelse {
            window.eventError = error.FailedToBindXdgWindowManagerBase;
            return;
        });
        
        window.xdgWindowManagerBaseListener = .{
            .ping = xdgWindowManagerBasePing
        };
        
        if (wayland.xdg_wm_base_add_listener(window.xdgWindowManagerBase,&window.xdgWindowManagerBaseListener,window) == -1) {
            window.eventError = error.FailedToAddXdgWindowManagerBaseListener;
            return;
        }
    }
    
    if (std.mem.eql(u8,std.mem.span(interface),"wl_seat")) {
        window.seat = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.wl_seat_interface,version) orelse {
            window.eventError = error.FailedToBindSeat;
            return;
        });
        
        // Initialize keyboard
        
        
            window.keyboard.keyboard = wayland.wl_seat_get_keyboard(window.seat) orelse {
                window.eventError = error.FailedToGetKeyboard;
                return;
            };
            
            window.keyboard.listener = .{
                .keymap = keyboardKeymap,
                .enter = keyboardEnter,
                .leave = keyboardLeave,
                .key = keyboardKey,
                .modifiers = keyboardModifiers,
                .repeat_info = keyboardRepeatInformation
            };
            
            if (wayland.wl_keyboard_add_listener(window.keyboard.keyboard,&window.keyboard.listener,window) == -1) {
                window.eventError = error.FailedToAddKeyboardListener;
                return;
            }
        
        
        // Initialize pointer
        
        
            window.pointer.pointer = wayland.wl_seat_get_pointer(window.seat) orelse {
                window.eventError = error.FailedToGetPointer;
                return;
            };
            
            window.pointer.listener = .{
                .enter = pointerEnter,
                .leave = pointerLeave,
                .motion = pointerMotion,
                .button = pointerButton,
                .axis = pointerAxis,
                .frame = pointerFrame,
                .axis_source = pointerAxisSource,
                .axis_stop = pointerAxisStop,
                .axis_discrete = pointerAxisDescrete,
                .axis_relative_direction = pointerAxisRelativeDirection,
                .axis_value120 = pointerAxisValue120
            };
            
            if (wayland.wl_pointer_add_listener(window.pointer.pointer,&window.pointer.listener,window) == -1) {
                window.eventError = error.FailedToAddPointerListener;
                return;
            }
    }
    
    if (std.mem.eql(u8,std.mem.span(interface),"wl_shm")) {
        window.sharedMemoryBuffer = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.wl_shm_interface,version) orelse {
            window.eventError = error.FailedToBindSharedMemoryBuffer;
            return;
        });
    }
}

fn xdgSurfaceConfigure(data: ?*anyopaque,xdgSurface: ?*wayland.xdg_surface,serial: u32) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    wayland.xdg_surface_ack_configure(xdgSurface,serial);
    
    if (window.sizeChanged) {
        window.base.eventBus.append(.{
            .resize = .{
                .x = @intCast(window.base.size[0]),
                .y = @intCast(window.base.size[1])
            }
        });
        
        window.sizeChanged = false;
    }
}

fn xdgWindowToplevelClose(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    window.base.eventBus.append(.{
        .close = {}
    });
    
    _ = xdgToplevel;
}

fn xdgWindowToplevelConfigure(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel,width: i32,height: i32,states: ?*wayland.wl_array) callconv(.c) void {
    const window: *Implementation = @ptrCast(@alignCast(data));
    
    if (width > 0 and height > 0 and (width != window.base.size[0] or height != window.base.size[1])) {
        window.base.size = .{
            @intCast(width),
            @intCast(height)
        };
        
        window.sizeChanged = true;
    }
    
    _ = xdgToplevel;
    _ = states;
}

fn xdgWindowToplevelConfigureBounds(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel,width: i32,height: i32) callconv(.c) void {
    _ = data;
    _ = xdgToplevel;
    _ = width;
    _ = height;
}

fn xdgWindowToplevelWindowManagerCapabilities(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel,capabilities: ?*wayland.wl_array) callconv(.c) void {
    _ = data;
    _ = xdgToplevel;
    _ = capabilities;
}

pub fn setCursor(self: *LinuxBackend,cursor: moduleMain.Pointer.Cursor) !void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    
    const cursorName: ?[*:0]const u8 = switch (cursor) {
        .Arrow => "default",
        .Pointer => "pointer",
        .Grab => "grab",
        .Grabbing => "grabbing",
        .Text => "text",
        .VerticalText => "vertical-text",
        .Crosshair => "crosshair",
        .ResizeTop => "n-resize",
        .ResizeBottom => "s-resize",
        .ResizeLeft => "w-resize",
        .ResizeRight => "e-resize",
        .ResizeTopLeft => "nw-resize",
        .ResizeTopRight => "ne-resize",
        .ResizeBottomLeft => "sw-resize",
        .ResizeBottomRight => "se-resize",
        .NotAllowed => "not-allowed",
        .Wait => "wait",
        .Progress => "progress",
        .Help => "help",
        .ContextMenu => "context-menu",
        .Copy => "copy",
        .Alias => "alias",
        .NoDrop => "no-drop",
        .ZoomIn => "zoom-in",
        .ZoomOut => "zoom-out",
        .Hidden => null
    };
    
    window.pointer.cursor = if (cursorName != null) wayland.wl_cursor_theme_get_cursor(window.pointer.theme,cursorName) else null;
    
    window.pointer.imageIndex = 0;
    window.pointer.updateTimestamp = meowUtilities.time.getUniversalTimestamp();
}

pub fn setCursorImage(self: *LinuxBackend,pixels: []const u8) void { // TODO: Implement
    const window: *Implementation = @ptrCast(@alignCast(self));
    _ = window; _ = pixels;
}

pub fn create(base: *moduleMain.Window.Base) !*LinuxBackend {
    const window: *Implementation = base.allocator.create(Implementation) catch unreachable;
    errdefer base.allocator.destroy(window);
    
    window.base = base;
    
    window.display = wayland.wl_display_connect(null) orelse return error.FailedToConnectDisplay;
    errdefer wayland.wl_display_disconnect(window.display);
    
    window.registry = wayland.wl_display_get_registry(window.display) orelse return error.FailedToGetRegistry;
    errdefer wayland.wl_registry_destroy(window.registry);
    
    window.eventError = null;
    
    window.xdgWindowManagerBase = null;
    window.seat = null;
    window.sharedMemoryBuffer = null;
    
    window.registryListener = .{
        .global = registryGlobal
    };
    
    if (wayland.wl_registry_add_listener(window.registry,&window.registryListener,window) == -1) return error.FailedToAddRegistryListener;
    
    if (wayland.wl_display_roundtrip(window.display) == -1) return error.FailedToPreformARoundTrip;
    errdefer {
        if (window.xdgWindowManagerBase != null) {
            wayland.xdg_wm_base_destroy(window.xdgWindowManagerBase);
        }
        
        if (window.seat != null) {
            wayland.wl_seat_destroy(window.seat);
        }
        
        if (window.sharedMemoryBuffer != null) {
            wayland.wl_shm_destroy(window.sharedMemoryBuffer);
        }
    }
    
    if (window.compositor == null or window.xdgWindowManagerBase == null or window.seat == null or window.sharedMemoryBuffer == null) {
        return error.MissingGlobals;
    }
    
    window.surface = wayland.wl_compositor_create_surface(window.compositor) orelse return error.FailedToCreateSurface;
    errdefer wayland.wl_surface_destroy(window.surface);
    
    window.xdgSurface = wayland.xdg_wm_base_get_xdg_surface(window.xdgWindowManagerBase,window.surface) orelse return error.FailedToGetXdgSurface;
    errdefer wayland.xdg_surface_destroy(window.xdgSurface);
    
    window.xdgSurfaceListener = .{
        .configure = xdgSurfaceConfigure
    };
    
    if (wayland.xdg_surface_add_listener(window.xdgSurface,&window.xdgSurfaceListener,window) == -1) return error.FailedToAddXdgSurfaceListener;
    
    switch (window.base.kind) {
        .Toplevel => {
            window.xdgWindow.toplevel = wayland.xdg_surface_get_toplevel(window.xdgSurface) orelse return error.FailedToGetXdgToplevel;
            
            window.xdgWindowListener.toplevel = wayland.xdg_toplevel_listener {
                .close = xdgWindowToplevelClose,
                .configure = xdgWindowToplevelConfigure,
                .configure_bounds = xdgWindowToplevelConfigureBounds,
                .wm_capabilities = xdgWindowToplevelWindowManagerCapabilities
            };
            
            if (wayland.xdg_toplevel_add_listener(window.xdgWindow.toplevel,&window.xdgWindowListener.toplevel,window) == -1) return error.FailedToAddXdgToplevelListener;
            
            wayland.xdg_toplevel_set_title(window.xdgWindow.toplevel,window.base.title);
        }
    }
    errdefer {
        switch (window.xdgWindow) {
            .toplevel => |toplevel| wayland.xdg_toplevel_destroy(toplevel)
        }
    }
    
    wayland.xdg_surface_set_window_geometry(window.xdgSurface,0,0,@intCast(window.base.size[0]),@intCast(window.base.size[1]));
    
    wayland.wl_surface_commit(window.surface);
    
    window.keyboard.repeatingEvent = null;
    
    // Initialize pointer cursor
    
    
        window.pointer.surface = wayland.wl_compositor_create_surface(window.compositor) orelse return error.FailedToCreateCursorSurface;
        errdefer wayland.wl_surface_destroy(window.pointer.surface);
        
        window.pointer.theme = wayland.wl_cursor_theme_load(null,24,window.sharedMemoryBuffer).?;
        
        try setCursor(@ptrCast(window),.Arrow);
    
    
    return @ptrCast(window);
}

pub fn destroy(self: *LinuxBackend) void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    
    wayland.xdg_toplevel_destroy(window.xdgWindow.toplevel);
    wayland.xdg_surface_destroy(window.xdgSurface);
    wayland.wl_surface_destroy(window.surface);
    wayland.xdg_wm_base_destroy(window.xdgWindowManagerBase);
    wayland.wl_surface_destroy(window.pointer.surface);
    wayland.wl_seat_destroy(window.seat);
    wayland.wl_registry_destroy(window.registry);
    wayland.wl_display_disconnect(window.display);
    
    window.base.allocator.destroy(window);
}

pub fn getRawHandles(self: *LinuxBackend) moduleMain.Window.RawHandles {
    const window: *Implementation = @ptrCast(@alignCast(self));
    
    return .{
        .wayland = .{
            .display = window.display,
            .surface = window.surface
        }
    };
}

pub fn stepMainLoop(self: *LinuxBackend) !void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    
    if (wayland.wl_display_dispatch_pending(window.display) == -1) return error.PendingDispatchEventsFailure;
    
    if (wayland.wl_display_prepare_read(window.display) < 0) {
        if (wayland.wl_display_flush(window.display) == -1) return error.EventFlushFailure;
        return;
    }
    
    const fileDescriptor: i32 = wayland.wl_display_get_fd(window.display);
    
    var fileDescriptorPollResult: stdC.pollfd = .{
        .fd = fileDescriptor,
        .events = stdC.POLLIN
    };
    
    if (stdC.poll(@ptrCast(&fileDescriptorPollResult),1,0) != -1 and (fileDescriptorPollResult.revents & stdC.POLLIN != 0)) {
        if (wayland.wl_display_read_events(window.display) == -1) {
            wayland.wl_display_cancel_read(window.display);
            return;
        }
        
        if (wayland.wl_display_dispatch_pending(window.display) == -1) return error.PendingDispatchEventsFailure;
    } else {
        wayland.wl_display_cancel_read(window.display);
    }
    
    const nowTimestamp: meowUtilities.time.Timestamp = meowUtilities.time.getUniversalTimestamp();
    
    // Keyboard input repetition
    
    
        if (window.keyboard.repeatTimestamp - nowTimestamp <= 0) {
            if (window.keyboard.repeatingEvent != null) {
                window.keyboard.repeatingEvent.?.timestamp = nowTimestamp;
                
                window.base.keyboardEventBus.append(.{
                    .repeat = window.keyboard.repeatingEvent.?
                });
                
                window.keyboard.repeatTimestamp = nowTimestamp + std.time.us_per_s / window.keyboard.repeatRate;
            }
        }
    
    
    // Update pointer cursor image
    
    
        if (window.pointer.updateTimestamp - nowTimestamp <= 0) {
            if (window.pointer.cursor != null) {
                window.pointer.imageIndex = (window.pointer.imageIndex + 1) % window.pointer.cursor.?.image_count;
                
                const image: *wayland.wl_cursor_image = window.pointer.cursor.?.images[window.pointer.imageIndex].?;
                
                wayland.wl_pointer_set_cursor(window.pointer.pointer,window.pointer.enterSerial,window.pointer.surface,@intCast(image.hotspot_x),@intCast(image.hotspot_y));
                
                wayland.wl_surface_attach(window.pointer.surface,wayland.wl_cursor_image_get_buffer(image),0,0);
                
                wayland.wl_surface_damage(window.pointer.surface,0,0,@intCast(image.width),@intCast(image.height));
                
                wayland.wl_surface_commit(window.pointer.surface);
                
                window.pointer.updateTimestamp = nowTimestamp + std.time.us_per_s / image.delay;
            } else {
                wayland.wl_pointer_set_cursor(window.pointer.pointer,window.pointer.enterSerial,null,0,0);
                
                window.pointer.updateTimestamp = nowTimestamp + @as(meowUtilities.time.Timestamp,@intFromFloat(0.1 * std.time.us_per_s));
            }
        }
    
    
    if (window.eventError != null) {
        return window.eventError.?;
    }
}

pub fn setFullscreen(self: *LinuxBackend,state: bool) void {
    const window: *Implementation = @ptrCast(@alignCast(self));
    
    if (state) {
        switch (window.xdgWindow) {
            .toplevel => |toplevel| wayland.xdg_toplevel_set_fullscreen(toplevel,null)
        }
    } else {
        switch (window.xdgWindow) {
            .toplevel => |toplevel| wayland.xdg_toplevel_unset_fullscreen(toplevel)
        }
    }
    
    window.base.state.fullscreen = state;
}
