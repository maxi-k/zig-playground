const std = @import("std");
const fctx = @import("fcontext.zig");

var ctx_main: fctx.FContext = .{ .sp = undefined };
var ctx_worker: fctx.FContext = .{ .sp = undefined };

fn worker(arg: ?*anyopaque) callconv(.C) noreturn {
    _ = arg;
    const stdout = std.io.getStdOut().writer();
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        _ = stdout.print("worker: iter {}\n", .{i}) catch {};
        fctx.jump(&ctx_worker, &ctx_main);
    }
    std.process.exit(0); // 0.14
}

pub fn main() !void {
    const alc = std.heap.page_allocator;

    const stack = try alc.alloc(u8, 64 * 1024);
    defer alc.free(stack);

    ctx_worker = fctx.make(stack, worker, null);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("main: switch -> worker\n", .{});
    fctx.jump(&ctx_main, &ctx_worker);

    try stdout.print("main: back 1\n", .{});
    fctx.jump(&ctx_main, &ctx_worker);

    try stdout.print("main: back 2\n", .{});
    fctx.jump(&ctx_main, &ctx_worker);

    try stdout.print("main: done\n", .{});
}
