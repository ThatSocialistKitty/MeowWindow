const std: type = @import("std");
const moduleMain: type = @import("../../main.zig");
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

base: *moduleMain.Window.Base = undefined,
display: *wayland.wl_display = undefined,
registry: *wayland.wl_registry = undefined,
eventError: ?anyerror = null,
registryListener: wayland.wl_registry_listener = undefined,
compositor: ?*wayland.wl_compositor = null,
xdgWindowManagerBase: ?*wayland.xdg_wm_base = null,
xdgWindowManagerBaseListener: wayland.xdg_wm_base_listener = undefined,
seat: ?*wayland.wl_seat = null,
keyboard: Keyboard = undefined,
pointer: Pointer = undefined,
sharedMemoryBuffer: ?*wayland.wl_shm = null,
surface: *wayland.wl_surface = undefined,
xdgSurface: *wayland.xdg_surface = undefined,
xdgSurfaceListener: wayland.xdg_surface_listener = undefined,
xdgToplevel: *wayland.xdg_toplevel = undefined,
xdgToplevelListener: wayland.xdg_toplevel_listener = undefined,
sizeChanged: bool = false,

const Keyboard: type = struct {
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
};

const Pointer: type = struct {
    pointer: *wayland.wl_pointer,
    listener: wayland.wl_pointer_listener,
    surface: *wayland.wl_surface,
    theme: *wayland.wl_cursor_theme,
    cursor: ?*wayland.wl_cursor,
    imageIndex: u32,
    updateTimestamp: meowUtilities.time.Timestamp,
    enterSerial: u32
};

fn xdgWindowManagerBasePing(data: ?*anyopaque,xdgWindowManagerBase: ?*wayland.xdg_wm_base,serial: u32) callconv(.c) void {
    wayland.xdg_wm_base_pong(xdgWindowManagerBase,serial);
    _ = data;
}

fn keyboardKeymap(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,format: u32,fileDescriptor: i32,size: u32) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    if (format != wayland.WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1) {
        _ = stdC.close(fileDescriptor);
        return;
    }
    
    const xkbContext: *wayland.xkb_context = wayland.xkb_context_new(wayland.XKB_CONTEXT_NO_FLAGS) orelse {
        self.eventError = error.FailedToCreateXkbContext;
        return;
    };
    
    const xkbKeymapString: [*:0]const u8 = @ptrCast(stdC.mmap(null,size,stdC.PROT_READ,stdC.MAP_SHARED,fileDescriptor,0).?);
    
    const xkbKeymap: *wayland.xkb_keymap = wayland.xkb_keymap_new_from_string(xkbContext,xkbKeymapString,wayland.XKB_KEYMAP_FORMAT_TEXT_V1,wayland.XKB_KEYMAP_COMPILE_NO_FLAGS) orelse {
        self.eventError = error.FailedToCreateXkbKeymap;
        return;
    };
    
    _ = stdC.munmap(@ptrCast(@constCast(xkbKeymapString)),size);
    _ = stdC.close(fileDescriptor);
    
    const xkbKeymapState: *wayland.xkb_state = wayland.xkb_state_new(xkbKeymap) orelse {
        self.eventError = error.FailedToCreateXkbState;
        return;
    };
    
    self.keyboard.xkbKeymap = xkbKeymap;
    self.keyboard.xkbKeymapState = xkbKeymapState;
    
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
    const self: *@This() = @ptrCast(@alignCast(data));
    
    const keycode: wayland.xkb_keycode_t = key + 8;
    
    const direction: c_uint = switch (state) {
        wayland.WL_KEYBOARD_KEY_STATE_PRESSED => wayland.XKB_KEY_DOWN,
        wayland.WL_KEYBOARD_KEY_STATE_RELEASED => wayland.XKB_KEY_UP,
        else => return
    };
    
    _ = wayland.xkb_state_update_key(self.keyboard.xkbKeymapState,keycode,direction);
    
    const keyCharacterLength: c_int = wayland.xkb_state_key_get_utf8(self.keyboard.xkbKeymapState,keycode,&self.keyboard.pressUnicode,self.keyboard.pressUnicode.len);
    
    const eventData: moduleMain.Keyboard.KeyEvent = .{
        .key = switch (wayland.xkb_state_key_get_one_sym(self.keyboard.xkbKeymapState,keycode)) {
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
        .unicode = if (keyCharacterLength > 0) self.keyboard.pressUnicode[0..@intCast(keyCharacterLength)] else null,
        .timestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io)
    };
    
    switch (state) {
        wayland.WL_KEYBOARD_KEY_STATE_PRESSED => {
            if (wayland.xkb_keymap_key_repeats(self.keyboard.xkbKeymap,keycode) == 1) {
                if (self.keyboard.repeatingEvent != null) {
                    self.keyboard.repeatingEvent = null;
                }
                
                if (eventData.unicode != null) {
                    @memcpy(&self.keyboard.repeatingUnicode,eventData.unicode.?.ptr);
                }
                
                self.keyboard.repeatingEvent = .{
                    .key = eventData.key,
                    .unicode = if (eventData.unicode != null) self.keyboard.repeatingUnicode[0..eventData.unicode.?.len] else null,
                    .timestamp = eventData.timestamp
                };
                
                self.keyboard.repeatTimestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io).addDuration(.fromMilliseconds(self.keyboard.repeatDelay));
            }
            
            self.base.keyboardEventBus.?.append(.{
                .press = eventData
            });
        },
        wayland.WL_KEYBOARD_KEY_STATE_RELEASED => {
            if (self.keyboard.repeatingEvent != null) {
                if (self.keyboard.repeatingEvent.?.key == eventData.key) {
                    self.keyboard.repeatingEvent = null;
                }
            }
            
            self.base.keyboardEventBus.?.append(.{
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
    const self: *@This() = @ptrCast(@alignCast(data));
    
    if (wayland.xkb_state_update_mask(self.keyboard.xkbKeymapState,depressedModifiers,latchedModifiers,lockedModifiers,0,0,group) == -1) {
        self.eventError = error.FailedToUpdateXkbMask;
        return;
    }
    
    _ = keyboard;
    _ = serial;
}

fn keyboardRepeatInformation(data: ?*anyopaque,keyboard: ?*wayland.wl_keyboard,rate: i32,delay: i32) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    self.keyboard.repeatRate = @intCast(rate);
    self.keyboard.repeatDelay = @intCast(delay);
    
    _ = keyboard;
}

fn pointerEnter(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,serial: u32,surface: ?*wayland.wl_surface,surfaceX: wayland.wl_fixed_t,surfaceY: wayland.wl_fixed_t) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    self.pointer.enterSerial = serial;
    
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
    const self: *@This() = @ptrCast(@alignCast(data));
    
    self.base.pointerEventBus.?.append(.{
        .move = .{
            .position = .{
                @floatFromInt(wayland.wl_fixed_to_int(surfaceX)),
                @floatFromInt(wayland.wl_fixed_to_int(surfaceY))
            },
            .timestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io)
        }
    });
    
    _ = pointer;
    _ = time;
}

fn pointerButton(data: ?*anyopaque,pointer: ?*wayland.wl_pointer,serial: u32,time: u32,button: u32,state: u32) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    const eventData: moduleMain.Pointer.ButtonEvent = .{
        .button = switch (button) {
            linux.BTN_LEFT => .Left,
            linux.BTN_RIGHT => .Right,
            linux.BTN_MIDDLE => .Middle,
            linux.BTN_EXTRA => .Next,
            linux.BTN_SIDE => .Previous,
            else => .Unknown
        },
        .timestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io)
    };
    
    switch (state) {
        wayland.WL_POINTER_BUTTON_STATE_PRESSED => {
            self.base.pointerEventBus.?.append(.{
                .press = eventData
            });
        },
        wayland.WL_POINTER_BUTTON_STATE_RELEASED => {
            self.base.pointerEventBus.?.append(.{
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
    const self: *@This() = @ptrCast(@alignCast(data));
    
    self.base.pointerEventBus.?.append(.{
        .scroll = .{
            .direction = if (wayland.wl_fixed_to_int(value) > 0) .Down else .Up,
            .timestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io)
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
    const self: *@This() = @ptrCast(@alignCast(data));
    
    if (std.mem.eql(u8,std.mem.span(interface),"wl_compositor")) {
        self.compositor = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.wl_compositor_interface,version) orelse {
            self.eventError = error.FailedToBindCompositor;
            return;
        });
    }
    
    if (std.mem.eql(u8,std.mem.span(interface),"xdg_wm_base")) {
        self.xdgWindowManagerBase = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.xdg_wm_base_interface,version) orelse {
            self.eventError = error.FailedToBindXdgWindowManagerBase;
            return;
        });
        
        self.xdgWindowManagerBaseListener = .{
            .ping = xdgWindowManagerBasePing
        };
        
        if (wayland.xdg_wm_base_add_listener(self.xdgWindowManagerBase,&self.xdgWindowManagerBaseListener,self) == -1) {
            self.eventError = error.FailedToAddXdgWindowManagerBaseListener;
            return;
        }
    }
    
    if (std.mem.eql(u8,std.mem.span(interface),"wl_seat")) {
        self.seat = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.wl_seat_interface,version) orelse {
            self.eventError = error.FailedToBindSeat;
            return;
        });
        
        // Initialize keyboard
        
        
            self.keyboard.keyboard = wayland.wl_seat_get_keyboard(self.seat) orelse {
                self.eventError = error.FailedToGetKeyboard;
                return;
            };
            
            self.keyboard.listener = .{
                .keymap = keyboardKeymap,
                .enter = keyboardEnter,
                .leave = keyboardLeave,
                .key = keyboardKey,
                .modifiers = keyboardModifiers,
                .repeat_info = keyboardRepeatInformation
            };
            
            if (wayland.wl_keyboard_add_listener(self.keyboard.keyboard,&self.keyboard.listener,self) == -1) {
                self.eventError = error.FailedToAddKeyboardListener;
                return;
            }
        
        
        // Initialize pointer
        
        
            self.pointer.pointer = wayland.wl_seat_get_pointer(self.seat) orelse {
                self.eventError = error.FailedToGetPointer;
                return;
            };
            
            self.pointer.listener = .{
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
            
            if (wayland.wl_pointer_add_listener(self.pointer.pointer,&self.pointer.listener,self) == -1) {
                self.eventError = error.FailedToAddPointerListener;
                return;
            }
    }
    
    if (std.mem.eql(u8,std.mem.span(interface),"wl_shm")) {
        self.sharedMemoryBuffer = @ptrCast(wayland.wl_registry_bind(registry,name,&wayland.wl_shm_interface,version) orelse {
            self.eventError = error.FailedToBindSharedMemoryBuffer;
            return;
        });
    }
}

fn xdgSurfaceConfigure(data: ?*anyopaque,xdgSurface: ?*wayland.xdg_surface,serial: u32) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    wayland.xdg_surface_ack_configure(xdgSurface,serial);
    
    if (self.sizeChanged) {
        self.base.eventBus.append(.{
            .resize = .{
                .x = @intCast(self.base.size[0]),
                .y = @intCast(self.base.size[1])
            }
        });
        
        self.sizeChanged = false;
    }
}

fn xdgWindowToplevelClose(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    self.base.eventBus.append(.{
        .close = {}
    });
    
    _ = xdgToplevel;
}

fn xdgWindowToplevelConfigure(data: ?*anyopaque,xdgToplevel: ?*wayland.xdg_toplevel,width: i32,height: i32,states: ?*wayland.wl_array) callconv(.c) void {
    const self: *@This() = @ptrCast(@alignCast(data));
    
    if (width > 0 and height > 0 and (width != self.base.size[0] or height != self.base.size[1])) {
        self.base.size = .{
            @intCast(width),
            @intCast(height)
        };
        
        self.sizeChanged = true;
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

pub fn create(base: *moduleMain.Window.Base) !*@This() {
    const self: *@This() = base.context.allocator.create(@This()) catch unreachable;
    errdefer base.context.allocator.destroy(self);
    
    self.eventError = null;
    self.compositor = null;
    self.xdgWindowManagerBase = null;
    self.seat = null;
    self.sharedMemoryBuffer = null;
    self.sizeChanged = false;
    
    self.base = base;
    
    self.display = wayland.wl_display_connect(null) orelse return error.FailedToConnectDisplay;
    errdefer wayland.wl_display_disconnect(self.display);
    
    self.registry = wayland.wl_display_get_registry(self.display) orelse return error.FailedToGetRegistry;
    errdefer wayland.wl_registry_destroy(self.registry);
    
    self.registryListener = .{
        .global = registryGlobal
    };
    
    if (wayland.wl_registry_add_listener(self.registry,&self.registryListener,self) == -1) return error.FailedToAddRegistryListener;
    
    if (wayland.wl_display_roundtrip(self.display) == -1) return error.FailedToPreformARoundTrip;
    errdefer {
        if (self.xdgWindowManagerBase != null) {
            wayland.xdg_wm_base_destroy(self.xdgWindowManagerBase);
        }
        
        if (self.seat != null) {
            wayland.wl_seat_destroy(self.seat);
        }
        
        if (self.sharedMemoryBuffer != null) {
            wayland.wl_shm_destroy(self.sharedMemoryBuffer);
        }
    }
    
    if (self.compositor == null or self.xdgWindowManagerBase == null or self.seat == null or self.sharedMemoryBuffer == null) {
        return error.MissingGlobals;
    }
    
    self.surface = wayland.wl_compositor_create_surface(self.compositor) orelse return error.FailedToCreateSurface;
    errdefer wayland.wl_surface_destroy(self.surface);
    
    self.xdgSurface = wayland.xdg_wm_base_get_xdg_surface(self.xdgWindowManagerBase,self.surface) orelse return error.FailedToGetXdgSurface;
    errdefer wayland.xdg_surface_destroy(self.xdgSurface);
    
    self.xdgSurfaceListener = .{
        .configure = xdgSurfaceConfigure
    };
    
    if (wayland.xdg_surface_add_listener(self.xdgSurface,&self.xdgSurfaceListener,self) == -1) return error.FailedToAddXdgSurfaceListener;
    
    switch (self.base.kind) {
        .Toplevel => {
            self.xdgToplevel = wayland.xdg_surface_get_toplevel(self.xdgSurface) orelse return error.FailedToGetXdgToplevel;
            
            self.xdgToplevelListener = .{
                .close = xdgWindowToplevelClose,
                .configure = xdgWindowToplevelConfigure,
                .configure_bounds = xdgWindowToplevelConfigureBounds,
                .wm_capabilities = xdgWindowToplevelWindowManagerCapabilities
            };
            
            if (wayland.xdg_toplevel_add_listener(self.xdgToplevel,&self.xdgToplevelListener,self) == -1) return error.FailedToAddXdgToplevelListener;
            
            wayland.xdg_toplevel_set_title(self.xdgToplevel,self.base.title);
        }
    }
    errdefer switch (self.base.kind) {
        .Toplevel => wayland.xdg_toplevel_destroy(self.xdgToplevel)
    };
    
    wayland.xdg_surface_set_window_geometry(self.xdgSurface,0,0,@intCast(self.base.size[0]),@intCast(self.base.size[1]));
    
    wayland.wl_surface_commit(self.surface);
    
    // Initialize pointer cursor
    
    
        self.pointer.surface = wayland.wl_compositor_create_surface(self.compositor) orelse return error.FailedToCreateCursorSurface;
        errdefer wayland.wl_surface_destroy(self.pointer.surface);
        
        self.pointer.theme = wayland.wl_cursor_theme_load(null,24,self.sharedMemoryBuffer).?;
        
        try setCursor(self,.Arrow);
    
    
    return self;
}

pub fn destroy(self: *@This()) void {
    switch (self.base.kind) {
        .Toplevel => wayland.xdg_toplevel_destroy(self.xdgToplevel)
    }
    
    wayland.xdg_surface_destroy(self.xdgSurface);
    wayland.wl_surface_destroy(self.surface);
    wayland.xdg_wm_base_destroy(self.xdgWindowManagerBase);
    wayland.wl_surface_destroy(self.pointer.surface);
    wayland.wl_seat_destroy(self.seat);
    wayland.wl_registry_destroy(self.registry);
    wayland.wl_display_disconnect(self.display);
    
    self.base.context.allocator.destroy(self);
}

pub fn getRawHandles(self: *@This()) moduleMain.Window.RawHandles {
    return .{
        .wayland = .{
            .display = self.display,
            .surface = self.surface
        }
    };
}

pub fn stepMainLoop(self: *@This()) !void {
    if (wayland.wl_display_dispatch_pending(self.display) == -1) return error.PendingDispatchEventsFailure;
    
    if (wayland.wl_display_prepare_read(self.display) < 0) {
        if (wayland.wl_display_flush(self.display) == -1) return error.EventFlushFailure;
        return;
    }
    
    const fileDescriptor: i32 = wayland.wl_display_get_fd(self.display);
    
    var fileDescriptorPollResult: stdC.pollfd = .{
        .fd = fileDescriptor,
        .events = stdC.POLLIN
    };
    
    if (stdC.poll(@ptrCast(&fileDescriptorPollResult),1,0) != -1 and (fileDescriptorPollResult.revents & stdC.POLLIN != 0)) {
        if (wayland.wl_display_read_events(self.display) == -1) {
            wayland.wl_display_cancel_read(self.display);
            return;
        }
        
        if (wayland.wl_display_dispatch_pending(self.display) == -1) return error.PendingDispatchEventsFailure;
    } else {
        wayland.wl_display_cancel_read(self.display);
    }
    
    const nowTimestamp: meowUtilities.time.Timestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io);
    
    // Keyboard input repetition
    
    
        if (self.keyboard.repeatTimestamp.nanoseconds - nowTimestamp.nanoseconds <= 0) {
            if (self.keyboard.repeatingEvent != null) {
                self.keyboard.repeatingEvent.?.timestamp = nowTimestamp;
                
                self.base.keyboardEventBus.?.append(.{
                    .repeat = self.keyboard.repeatingEvent.?
                });
                
                self.keyboard.repeatTimestamp = nowTimestamp.addDuration(.fromMicroseconds(std.time.us_per_s / self.keyboard.repeatRate));
            }
        }
    
    
    // Update pointer cursor image
    
    
        if (self.pointer.updateTimestamp.nanoseconds - nowTimestamp.nanoseconds <= 0) {
            if (self.pointer.cursor != null) {
                self.pointer.imageIndex = (self.pointer.imageIndex + 1) % self.pointer.cursor.?.image_count;
                
                const image: *wayland.wl_cursor_image = self.pointer.cursor.?.images[self.pointer.imageIndex].?;
                
                wayland.wl_pointer_set_cursor(self.pointer.pointer,self.pointer.enterSerial,self.pointer.surface,@intCast(image.hotspot_x),@intCast(image.hotspot_y));
                
                wayland.wl_surface_attach(self.pointer.surface,wayland.wl_cursor_image_get_buffer(image),0,0);
                
                wayland.wl_surface_damage(self.pointer.surface,0,0,@intCast(image.width),@intCast(image.height));
                
                wayland.wl_surface_commit(self.pointer.surface);
                
                self.pointer.updateTimestamp = nowTimestamp.addDuration(.fromMilliseconds(image.delay));
            } else {
                wayland.wl_pointer_set_cursor(self.pointer.pointer,self.pointer.enterSerial,null,0,0);
                
                self.pointer.updateTimestamp = nowTimestamp.addDuration(.fromMilliseconds(100));
            }
        }
    
    
    if (self.eventError != null) {
        return self.eventError.?;
    }
}

pub fn setFullscreen(self: *@This(),state: bool) void {
    if (state) {
        switch (self.base.kind) {
            .Toplevel => wayland.xdg_toplevel_set_fullscreen(self.xdgToplevel,null)
        }
    } else {
        switch (self.base.kind) {
            .Toplevel => wayland.xdg_toplevel_unset_fullscreen(self.xdgToplevel)
        }
    }
    
    self.base.state.fullscreen = state;
}

pub fn setCursor(self: *@This(),cursor: moduleMain.Pointer.Cursor) !void {
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
    
    self.pointer.cursor = if (cursorName != null) wayland.wl_cursor_theme_get_cursor(self.pointer.theme,cursorName) else null;
    
    self.pointer.imageIndex = 0;
    self.pointer.updateTimestamp = meowUtilities.time.getUniversalTimestamp(self.base.context.io);
}

pub fn setCursorImage(self: *@This(),pixels: []const u8) void { // TODO: Implement
    _ = self; _ = pixels;
}
