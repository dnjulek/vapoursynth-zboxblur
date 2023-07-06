const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "zboxblur",
        .root_source_file = .{ .path = "src/zboxblur.zig" },
        .target = target,
        .optimize = optimize,
    });

    var vs_default_path = if (target.isWindows()) "C:/Program Files/VapourSynth/sdk/include" else "/usr/include";
    const vsinclude = b.option([]const u8, "vsinclude", "Custom path to VapourSynth include");
    var includes = if (vsinclude != null) vsinclude.? else vs_default_path;
    lib.addIncludePath(includes);
    lib.linkLibC();

    if (lib.optimize == .ReleaseFast) {
        lib.strip = true;
    }

    b.installArtifact(lib);
}
