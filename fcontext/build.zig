const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "fcontext-example",
        .root_source_file = b.path("example.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the external assembly object (AT&T syntax GAS).
    exe.addAssemblyFile(b.path("fcontext_x86_64_sysv.S"));

    b.installArtifact(exe);

    // `zig build run` (args forwarded: `zig build run -- arg1 arg2`)
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the fcontext example");
    run_step.dependOn(&run_cmd.step);
}
