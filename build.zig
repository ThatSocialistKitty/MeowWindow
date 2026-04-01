const std: type = @import("std");

fn addSourceFiles(b: *std.Build,library: *std.Build.Step.Compile,path: std.Build.LazyPath,flags: ?[]const []const u8,blacklist: ?[]const []const u8) void {
    var loaderDirectory: std.fs.Dir = std.fs.openDirAbsolute(path.getPath(b),.{
        .iterate = true,
        .access_sub_paths = true
    }) catch unreachable;
    defer loaderDirectory.close();
    
    var loaderDirectoryIterator: std.fs.Dir.Iterator = loaderDirectory.iterate();
    
    var sourceFiles: std.ArrayList([]const u8) = .empty;
    defer sourceFiles.deinit(b.allocator);
    
    while (loaderDirectoryIterator.next() catch unreachable) |entry| {
        var blacklisted: bool = false;
        
        if (blacklist != null) {
            for (blacklist.?) |fileName| {
                if (std.mem.eql(u8,fileName,entry.name)) {
                    blacklisted = true;
                }
            }
        }
        
        if (if (blacklist != null) !blacklisted else false) {
            switch (entry.kind) {
                .file => if (std.mem.endsWith(u8,entry.name,".c")) {
                    sourceFiles.append(b.allocator,
                        (path.join(b.allocator,entry.name) catch unreachable).getDisplayName()
                    ) catch unreachable;
                },
                .directory => {
                    addSourceFiles(b,library,path.join(b.allocator,entry.name) catch unreachable,flags,blacklist);
                },
                else => {}
            }
        }
    }
    
    library.root_module.addCSourceFiles(.{
        .files = sourceFiles.items,
        .flags = flags orelse &.{}
    });
}

pub fn build(b: *std.Build) !void {
    const target: std.Build.ResolvedTarget = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.standardOptimizeOption(.{});
    
    const mainModule: *std.Build.Module = b.addModule("main",.{
        .root_source_file = b.path("source/main.zig"),
        .target = target,
        .optimize = optimize
    });
    
    {
        const dependency: *std.Build.Dependency = b.dependency("MeowUtilities",.{
            .target = target,
            .optimize = optimize
        });
        
        mainModule.addImport(
            "MeowUtilities",
            dependency.module("main")
        );
    }
    
    mainModule.link_libc = true;
    
    switch (target.result.os.tag) {
        .linux => {
            mainModule.addIncludePath(b.path("platformSpecificSource/linux"));
            mainModule.addCSourceFile(.{
                .file = b.path("platformSpecificSource/linux/xdg-shell-protocol.c")
            });
            
            mainModule.linkSystemLibrary("wayland-client",.{});
            mainModule.linkSystemLibrary("xkbcommon",.{});
        },
        else => {}
    }
    
    // const dependenciesLibrary: *std.Build.Step.Compile = b.addLibrary(.{
    //     .name = "dependencies",
    //     .root_module = b.createModule(.{
    //         .target = target,
    //         .optimize = optimize,
    //         .link_libc = true,
    //         .pic = true
    //     })
    // });
    //
    // {
    //     dependenciesLibrary.addIncludePath(b.path("dependencies/Vulkan-Headers/include"));
    //
    //     const loaderDirectoryPath: std.Build.LazyPath = b.path("dependencies/Vulkan-Loader/loader");
    //     dependenciesLibrary.root_module.addIncludePath(loaderDirectoryPath);
    //     dependenciesLibrary.root_module.addIncludePath(loaderDirectoryPath.join(b.allocator,"generated") catch unreachable);
    //     addSourceFiles(b,dependenciesLibrary,loaderDirectoryPath,
    //         &.{
    //             "-DVK_ENABLE_BETA_EXTENSIONS",
    //             // "-DVK_USE_PLATFORM_WIN32_KHR", // TODO: windows only
    //             "-DVK_USE_PLATFORM_METAL_EXT",
    //             // "-DVK_USE_PLATFORM_MACOS_MVK", // TODO: macos only
    //             "-DFALLBACK_CONFIG_DIRS=\"/etc/xdg\"",
    //             "-DFALLBACK_DATA_DIRS=\"/usr/local/share:/usr/share\"",
    //             "-DSYSCONFDIR=\"/run/opengl-driver/share/\""
    //         },
    //         &.{
    //             "dlopen_fuchsia.h",
    //             "dlopen_fuchsia.c",
    //             "loader_windows.h", // TODO: Exclude when targetting windows
    //             "loader_windows.c",
    //             "dirent_on_windows.h",
    //             "dirent_on_windows.c"
    //         }
    //     );
    //
    //     b.installArtifact(dependenciesLibrary);
    // }
    
    // Once using Vulkan-Loader delete dis :p
    mainModule.linkSystemLibrary("vulkan",.{});
 }
