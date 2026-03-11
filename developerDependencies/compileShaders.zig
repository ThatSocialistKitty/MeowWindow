const std: type = @import("std");

pub fn main(b: *std.Build,shaderSourceDirectoryPath: std.Build.LazyPath) void {
    const compileShaders: *std.Build.Step = b.step("shaders","");
    
    const compiledShadersIntermediateDirectoryPath: []const u8 = b.makeTempPath();
    
    var shaderSourceDirectory: std.fs.Dir = std.fs.openDirAbsolute(shaderSourceDirectoryPath.getPath(b),.{
        .iterate = true
    }) catch unreachable;
    defer shaderSourceDirectory.close();
    
    var shaderSourceDirectoryIterator: std.fs.Dir.Iterator = shaderSourceDirectory.iterate();
    
    while (shaderSourceDirectoryIterator.next() catch unreachable) |entry| {
        const outputName: []const u8 = std.mem.concat(b.allocator,u8,&.{entry.name,".spv"}) catch unreachable;
        defer b.allocator.free(outputName);
        
        const outputPath: []const u8 = b.pathJoin(&.{compiledShadersIntermediateDirectoryPath,outputName});
        defer b.allocator.free(outputPath);
        
        const compileCommand: *std.Build.Step.Run = b.addSystemCommand(&.{"glslc","-o",outputPath,shaderSourceDirectoryPath.path(b,entry.name).getPath(b)});
        compileShaders.dependOn(&compileCommand.step);
    }
    
    const installShaderDirectory: *std.Build.Step.InstallDir = b.addInstallDirectory(.{
        .source_dir = b.path(compiledShadersIntermediateDirectoryPath),
        .install_dir = .bin,
        .install_subdir = "shaders"
    });
    
    installShaderDirectory.step.dependOn(compileShaders);
    b.getInstallStep().dependOn(&installShaderDirectory.step);
}
