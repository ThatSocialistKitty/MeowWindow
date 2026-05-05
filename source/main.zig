const std: type = @import("std");
const builtin: type = @import("builtin");
const meowUtilities: type = @import("MeowUtilities");

const Backend: type = switch (builtin.target.os.tag) {
   .linux => @import("backends/linux.zig"),
   else => |target| @compileError("There is no window backend implementation for \"" ++ @tagName(target) ++ "\"")
};

pub const Window: type = opaque {
    // TODO: Create da other events meow :3
    
    const EventBus: type = meowUtilities.miscellaneous.EventBus(union(enum) {
        close: void,
        resize: struct {
            x: u32,
            y: u32
        },
        // maximize: ,
        // minimize: ,
        // fullscreen: ,
        // focus: ,
        // unfocus: 
    });
    
    const Kind: type = enum {
        Toplevel
    };
    
    pub const Base: type = struct {
        allocator: std.mem.Allocator,
        title: [*:0]const u8,
        size: [2]u32,
        kind: Kind,
        fullscreenKey: ?Keyboard.Key,
        running: bool,
        state: struct {
            fullscreen: bool
        },
        eventBus: *EventBus,
        // displayEventBus: *Display.EventBus,
        keyboardEventBus: *Keyboard.EventBus,
        pointerEventBus: *Pointer.EventBus,
        // touchEventBus: *Touch.EventBus
    };
    
    const Implementation: type = struct {
        base: Base,
        // display: struct {
        //     keyboard: *Display,
        //     state: struct {
        //         
        //     }
        // },
        keyboard: ?struct {
            keyboard: *Keyboard,
            state: struct {
                heldKeys: std.bit_set.IntegerBitSet(@typeInfo(Keyboard.Key).@"enum".fields.len)
            }
        },
        pointer: ?struct {
            pointer: *Pointer,
            state: struct {
                heldButtons: std.bit_set.IntegerBitSet(@typeInfo(Pointer.Button).@"enum".fields.len),
                cursorPosition: [2]f32
            }
        },
        // touch: ?struct {
        //     touch: *Touch,
        //     state: struct {
        //         
        //     }
        // },
        backend: *Backend
    };
    
    const Configuration: type = struct {
        kind: Kind = .Toplevel
    };
    
    pub fn create(allocator: std.mem.Allocator,title: []const u8,size: [2]u32,configuration: Configuration) !*@This() {
        const window: *Implementation = allocator.create(Implementation) catch unreachable;
        errdefer allocator.destroy(window);
        
        window.base.allocator = allocator;
        
        window.base.title = window.base.allocator.dupeZ(u8,title) catch unreachable;
        errdefer window.base.allocator.free(std.mem.span(window.base.title));
        
        window.base.size = size;
        window.base.kind = configuration.kind;
        window.base.fullscreenKey = .F11;
        window.base.running = true;
        window.base.state = std.mem.zeroes(@TypeOf(window.base.state));
        
        window.base.eventBus = .create(window.base.allocator);
        errdefer window.base.eventBus.destroy();
        
        window.base.keyboardEventBus = .create(window.base.allocator);
        errdefer window.base.keyboardEventBus.destroy();
        
        window.base.pointerEventBus = .create(window.base.allocator);
        errdefer window.base.pointerEventBus.destroy();
        
        window.keyboard = .{
            .keyboard = .create(window),
            .state = std.mem.zeroes(@TypeOf(window.keyboard.?.state))
        };
        errdefer window.keyboard.?.keyboard.destroy();
        
        window.pointer = .{
            .pointer = .create(window),
            .state = std.mem.zeroes(@TypeOf(window.pointer.?.state))
        };
        errdefer window.pointer.?.pointer.destroy();
        
        window.backend = try .create(&window.base);
        errdefer window.backend.destroy();
        
        return @ptrCast(window);
    }
    
    pub fn destroy(self: *@This()) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        
        window.base.allocator.free(std.mem.span(window.base.title));
        window.base.eventBus.destroy();
        window.base.keyboardEventBus.destroy();
        window.base.pointerEventBus.destroy();
        window.keyboard.?.keyboard.destroy();
        window.pointer.?.pointer.destroy();
        window.backend.destroy();
        
        window.base.allocator.destroy(window);
    }
    
    pub const RawHandles: type = union(enum) {
        wayland: struct {
            display: *anyopaque,
            surface: *anyopaque
        }
    };
    
    pub fn getRawHandles(self: *@This()) RawHandles {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.backend.getRawHandles();
    }
    
    pub fn getSizePointer(self: *@This()) *const [2]u32 {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return &window.base.size;
    }
    
    pub fn stepMainLoop(self: *@This()) bool {
        const window: *Implementation = @ptrCast(@alignCast(self));
        
        while (window.base.eventBus.poll()) |event| {
            event.consume = true;
            
            switch (event.data) {
                .close => self.close(),
                else => continue
            }
        }
        
        while (window.base.keyboardEventBus.poll()) |event| {
            event.consume = true;
            
            switch (event.data) {
                .press => |data| {
                    window.keyboard.?.state.heldKeys.set(@intFromEnum(data.key));
                    
                    if (window.base.fullscreenKey != null) {
                        if (data.key == window.base.fullscreenKey.?) {
                            self.setFullscreen(!self.getFullscreen());
                        }
                    }
                },
                .release => |data| {
                    window.keyboard.?.state.heldKeys.unset(@intFromEnum(data.key));
                },
                else => continue
            }
        }
        
        while (window.base.pointerEventBus.poll()) |event| {
            event.consume = true;
            
            switch (event.data) {
                .press => |data| {
                    window.pointer.?.state.heldButtons.set(@intFromEnum(data.button));
                },
                .release => |data| {
                    window.pointer.?.state.heldButtons.unset(@intFromEnum(data.button));
                },
                else => continue
            }
        }
        
        window.backend.stepMainLoop() catch unreachable;
        
        return window.base.running;
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.base.eventBus.poll();
    }
    
    pub fn close(self: *@This()) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        window.base.running = false;
    }
    
    pub fn getSize(self: *@This()) [2]u32 {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.base.size;
    }
    
    pub fn setFullscreen(self: *@This(),state: bool) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        window.backend.setFullscreen(state);
    }
    
    pub fn getFullscreen(self: *@This()) bool {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.base.state.fullscreen;
    }
    
    pub fn setFullscreenKey(self: *@This(),key: ?Keyboard.Key) void {
        const window: *Implementation = @ptrCast(@alignCast(self));
        window.base.fullscreenKey = key;
    }
    
    // ...
    
    pub fn getKeyboard(self: *@This()) ?*Keyboard {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.keyboard.?.keyboard;
    }
    
    pub fn getPointer(self: *@This()) ?*Pointer {
        const window: *Implementation = @ptrCast(@alignCast(self));
        return window.pointer.?.pointer;
    }
};

pub const Keyboard: type = opaque {
    pub const Key: type = enum {
        A,
        B,
        C,
        D,
        E,
        F,
        G,
        H,
        I,
        J,
        K,
        L,
        M,
        N,
        O,
        P,
        Q,
        R,
        S,
        T,
        U,
        V,
        W,
        X,
        Y,
        Z,
        a,
        b,
        c,
        d,
        e,
        f,
        g,
        h,
        i,
        j,
        k,
        l,
        m,
        n,
        o,
        p,
        q,
        r,
        s,
        t,
        u,
        v,
        w,
        x,
        y,
        z,
        Zero,
        One,
        Two,
        Three,
        Four,
        Five,
        Six,
        Seven,
        Eight,
        Nine,
        F1,
        F2,
        F3,
        F4,
        F5,
        F6,
        F7,
        F8,
        F9,
        F10,
        F11,
        F12,
        F13,
        F14,
        F15,
        F16,
        F17,
        F18,
        F19,
        F20,
        F21,
        F22,
        F23,
        F24,
        Escape,
        Enter,
        Tab,
        Space,
        Backspace,
        Delete,
        Insert,
        LeftShift,
        RightShift,
        LeftControl,
        RightControl,
        LeftAlt,
        RightAlt,
        LeftSuper,
        RightSuper,
        Menu,
        Up,
        Down,
        Left,
        Right,
        Home,
        End,
        PageUp,
        PageDown,
        GraveAccent,
        Tilde,
        Minus,
        Equals,
        LeftBracket,
        RightBracket,
        Backslash,
        Pipe,
        Semicolon,
        Apostrophe,
        Comma,
        Period,
        Slash,
        NumpadZero,
        NumpadOne,
        NumpadTwo,
        NumpadThree,
        NumpadFour,
        NumpadFive,
        NumpadSix,
        NumpadSeven,
        NumpadEight,
        NumpadNine,
        NumpadDecimal,
        NumpadDivide,
        NumpadMultiply,
        NumpadSubtract,
        NumpadAdd,
        NumpadEnter,
        NumpadEquals,
        MediaPlay,
        MediaPause,
        MediaStop,
        MediaNextTrack,
        MediaPreviousTrack,
        VolumeUp,
        VolumeDown,
        Mute,
        Unknown
    };
    
    pub const KeyEvent: type = struct {
        key: Key,
        unicode: ?[]u8,
        timestamp: meowUtilities.time.Timestamp
    };
    
    const EventBus: type = meowUtilities.miscellaneous.EventBus(union(enum) {
        press: KeyEvent,
        repeat: KeyEvent,
        release: KeyEvent
    });
    
    const Implementation: type = struct {
        window: *Window.Implementation
    };
    
    fn create(window: *Window.Implementation) *@This() {
        const keyboard: *Implementation = window.base.allocator.create(Implementation) catch unreachable;
        keyboard.window = window;
        return @ptrCast(keyboard);
    }
    
    fn destroy(self: *@This()) void {
        const keyboard: *Implementation = @ptrCast(@alignCast(self));
        keyboard.window.base.allocator.destroy(keyboard);
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        const keyboard: *Implementation = @ptrCast(@alignCast(self));
        return keyboard.window.base.keyboardEventBus.poll();
    }
    
    pub fn isKeyDown(self: *@This(),key: Keyboard.Key) bool {
        const keyboard: *Implementation = @ptrCast(@alignCast(self));
        return keyboard.window.keyboard.?.state.heldKeys.isSet(@intFromEnum(key));
    }
};

pub const Pointer: type = opaque {
    pub const Button: type = enum {
        Left,
        Right,
        Middle,
        Next,
        Previous,
        Unknown
    };
    
    pub const ButtonEvent: type = struct {
        button: Button,
        timestamp: meowUtilities.time.Timestamp
    };
    
    pub const ScrollEvent: type = struct {
        direction: enum {
            Up,
            Down
        },
        timestamp: meowUtilities.time.Timestamp
    };
    
    pub const MoveEvent: type = struct {
        position: [2]f32,
        timestamp: meowUtilities.time.Timestamp
    };
    
    const EventBus: type = meowUtilities.miscellaneous.EventBus(union(enum) {
        press: ButtonEvent,
        release: ButtonEvent,
        scroll: ScrollEvent,
        move: MoveEvent
    });
    
    pub const Cursor: type = enum {
        Arrow,
        Pointer,
        Grab,
        Grabbing,
        Text,
        VerticalText,
        Crosshair,
        ResizeTop,
        ResizeBottom,
        ResizeLeft,
        ResizeRight,
        ResizeTopLeft,
        ResizeTopRight,
        ResizeBottomLeft,
        ResizeBottomRight,
        NotAllowed,
        Wait,
        Progress,
        Help,
        ContextMenu,
        Copy,
        Alias,
        NoDrop,
        ZoomIn,
        ZoomOut,
        Hidden
    };
    
    const Implementation: type = struct {
        window: *Window.Implementation
    };
    
    fn create(window: *Window.Implementation) *@This() {
        const pointer: *Implementation = window.base.allocator.create(Implementation) catch unreachable;
        pointer.window = window;
        return @ptrCast(pointer);
    }
    
    fn destroy(self: *@This()) void {
        const pointer: *Implementation = @ptrCast(@alignCast(self));
        pointer.window.base.allocator.destroy(pointer);
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        const pointer: *Implementation = @ptrCast(@alignCast(self));
        return pointer.window.base.pointerEventBus.poll();
    }
    
    
    
    pub fn isButtonDown(self: *@This(),button: Pointer.Button) bool {
        const pointer: *Implementation = @ptrCast(@alignCast(self));
        return pointer.window.pointer.?.state.heldButtons.isSet(@intFromEnum(button));
    }
    
    pub fn setCursor(self: *@This(),cursor: Cursor) !void {
        const pointer: *Implementation = @ptrCast(@alignCast(self));
        try pointer.window.backend.setCursor(cursor);
    }
};
