const std: type = @import("std");
const builtin: type = @import("builtin");
const meowUtilities: type = @import("MeowUtilities");

const Backend: type = union(enum) {
    wayland: *@import("backends/linux/wayland.zig")
};

pub const Context: type = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    environMap: *std.process.Environ.Map,
    
    pub fn create(allocator: std.mem.Allocator,io: std.Io,environMap: *std.process.Environ.Map) Context {
        var self: @This() = undefined;
        
        self.allocator = allocator;
        self.io = io;
        self.environMap = environMap;
        
        return self;
    }
    
    pub fn createWindow(self: *@This(),title: []const u8,size: [2]u32,configuration: Window.Configuration) !Window {
        return try .create(self,title,size,configuration);
    }
};

pub const Window: type = struct {
    base: *Base = undefined,
    backend: Backend = undefined,
    inputDevices: InputDevices = .{},
    
    const InputDevices: type = struct {
        // display: *Display = undefined,
        // displayState: DisplayState = .{},
        keyboard: ?Keyboard = null,
        keyboardState: ?KeyboardState = .{},
        pointer: ?Pointer = null,
        pointerState: ?PointerState = .{},
        // touch: *Touch = undefined,
        // touchState: TouchState = .{},
        
        const KeyboardState: type = struct {
            heldKeys: std.bit_set.IntegerBitSet(@typeInfo(Keyboard.Key).@"enum".fields.len) = .empty
        };
        
        const PointerState: type = struct {
            heldButtons: std.bit_set.IntegerBitSet(@typeInfo(Pointer.Button).@"enum".fields.len) = .empty,
            cursorPosition: [2]f32 = .{0,0}
        };
    };
    
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
        context: *Context,
        title: [*:0]const u8,
        size: [2]u32,
        kind: Kind,
        fullscreenKey: ?Keyboard.Key,
        running: bool,
        state: State,
        eventBus: EventBus,
        // displayEventBus: Display.EventBus,
        keyboardEventBus: ?Keyboard.EventBus,
        pointerEventBus: ?Pointer.EventBus,
        // touchEventBus: ?Touch.EventBus,
        
        const State: type = struct {
            fullscreen: bool = false
        };
    };
    
    const Configuration: type = struct {
        kind: ?Kind = null
    };
    
    fn create(context: *Context,title: []const u8,size: [2]u32,configuration: Configuration) !@This() {
        var self: @This() = .{};
        
        self.base = context.allocator.create(Base) catch unreachable;
        errdefer context.allocator.destroy(self.base);
        
        self.base.kind = .Toplevel;
        self.base.fullscreenKey = .F11;
        self.base.running = true;
        self.base.state = .{};
        self.base.keyboardEventBus = null;
        self.base.pointerEventBus = null;
        
        self.base.context = context;
        
        self.base.title = self.base.context.allocator.dupeZ(u8,title) catch unreachable;
        errdefer self.base.context.allocator.free(std.mem.span(self.base.title));
        
        self.base.size = size;
        
        inline for (@typeInfo(@TypeOf(self)).@"struct".fields) |field| {
            if (@hasField(@TypeOf(configuration),field.name)) {
                const value = @field(configuration,field.name);
                
                if (value != null) {
                    @field(self,field.name) = value.?;
                }
            }
        }
        
        self.base.eventBus = .create(self.base.context.allocator);
        errdefer self.base.eventBus.destroy();
        
        // Keyboard
        
        
            self.inputDevices.keyboard = .create(&self);
            
            self.base.keyboardEventBus = .create(self.base.context.allocator);
            errdefer self.base.keyboardEventBus.?.destroy();
        
        
        // Pointer
        
        
            self.inputDevices.pointer = .create(&self);
            
            self.base.pointerEventBus = .create(self.base.context.allocator);
            errdefer self.base.pointerEventBus.?.destroy();
        
        
        self.backend = switch (builtin.target.os.tag) {
            .linux => if (std.mem.eql(u8,self.base.context.environMap.get("XDG_SESSION_TYPE") orelse "","wayland"))
                    .{
                       .wayland = try .create(self.base)
                    }
                else
                    return error.X11NotSupported,
            // .windows => .{
            //     .windows = Backend.Windows.create(self.base)
            // },
            else => |target| @compileError("Missing backend for \"" ++ @tagName(target) ++ "\"")
        };
        errdefer switch (self.backend) {
            inline else => |backend| backend.destroy()
        };
        
        return self;
    }
    
    pub fn destroy(self: *@This()) void {
        switch (self.backend) {
            inline else => |backend| backend.destroy()
        }
        
        if (self.inputDevices.pointer != null) {
            self.base.pointerEventBus.?.destroy();
        }
        
        if (self.inputDevices.keyboard != null) {
            self.base.keyboardEventBus.?.destroy();
        }
        
        self.base.eventBus.destroy();
        
        self.base.context.allocator.free(std.mem.span(self.base.title));
        
        self.base.context.allocator.destroy(self.base);
    }
    
    pub const RawHandles: type = union(enum) {
        wayland: struct {
            display: *anyopaque,
            surface: *anyopaque
        }
    };
    
    pub fn getRawHandles(self: @This()) RawHandles {
        return switch (self.backend) {
            inline else => |backend| backend.getRawHandles()
        };
    }
    
    pub fn getSizePointer(self: @This()) *const [2]u32 {
        return &self.base.size;
    }
    
    pub fn stepMainLoop(self: *@This()) bool {
        while (self.base.eventBus.poll()) |event| {
            event.consume = true;
            
            switch (event.data) {
                .close => self.close(),
                else => continue
            }
        }
        
        if (self.inputDevices.keyboard != null) {
            while (self.base.keyboardEventBus.?.poll()) |event| {
                event.consume = true;
                
                switch (event.data) {
                    .press => |data| {
                        self.inputDevices.keyboardState.?.heldKeys.set(@intFromEnum(data.key));
                        
                        if (self.base.fullscreenKey != null) {
                            if (data.key == self.base.fullscreenKey.?) {
                                self.setFullscreen(!self.getFullscreen());
                            }
                        }
                    },
                    .release => |data| self.inputDevices.keyboardState.?.heldKeys.unset(@intFromEnum(data.key)),
                    else => continue
                }
            }
        }
        
        if (self.inputDevices.pointer != null) {
            while (self.base.pointerEventBus.?.poll()) |event| {
                event.consume = true;
                
                switch (event.data) {
                    .press => |data| self.inputDevices.pointerState.?.heldButtons.set(@intFromEnum(data.button)),
                    .release => |data| self.inputDevices.pointerState.?.heldButtons.unset(@intFromEnum(data.button)),
                    else => continue
                }
            }
        }
        
        switch (self.backend) {
            inline else => |backend| backend.stepMainLoop() catch {}
        }
        
        return self.base.running;
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        return self.base.eventBus.poll();
    }
    
    pub fn close(self: *@This()) void {
        self.base.running = false;
    }
    
    pub fn getSize(self: @This()) [2]u32 {
        return self.base.size;
    }
    
    pub fn setFullscreen(self: *@This(),state: bool) void {
        switch (self.backend) {
            inline else => |backend| backend.setFullscreen(state)
        }
    }
    
    pub fn getFullscreen(self: @This()) bool {
        return self.base.state.fullscreen;
    }
    
    pub fn setFullscreenKey(self: @This(),key: ?Keyboard.Key) void {
        self.base.fullscreenKey = key;
    }
    
    // ...
    
    pub fn getKeyboard(self: @This()) ?Keyboard {
        return self.inputDevices.keyboard;
    }
    
    pub fn getPointer(self: @This()) ?Pointer {
        return self.inputDevices.pointer;
    }
};

pub const Keyboard: type = struct {
    window: *Window,
    
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
    
    fn create(window: *Window) @This() {
        var self: @This() = undefined;
        self.window = window;
        return self;
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        return self.window.base.keyboardEventBus.?.poll();
    }
    
    pub fn isKeyDown(self: @This(),key: Keyboard.Key) bool {
        return self.window.inputDevices.keyboardState.?.heldKeys.isSet(@intFromEnum(key));
    }
};

pub const Pointer: type = struct {
    window: *Window,
    
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
    
    fn create(window: *Window) @This() {
        var self: @This() = undefined;
        self.window = window;
        return self;
    }
    
    pub fn pollEvents(self: *@This()) ?*EventBus.Event {
        return self.window.base.pointerEventBus.?.poll();
    }
    
    pub fn isButtonDown(self: @This(),button: Pointer.Button) bool {
        return self.window.inputDevices.pointerState.?.heldButtons.isSet(@intFromEnum(button));
    }
    
    pub fn setCursor(self: *@This(),cursor: Cursor) !void {
        switch (self.backend) {
            inline else => |backend| try backend.setCursor(cursor)
        }
    }
};
