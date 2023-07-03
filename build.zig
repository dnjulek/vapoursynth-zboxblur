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

    lib.addIncludePath("src/include");
    lib.linkLibC();
    lib.strip = true;

    b.installArtifact(lib);
}
