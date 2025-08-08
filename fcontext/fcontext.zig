const std = @import("std");

// A continuation == a stack pointer, prepared with saved registers to return to
pub const FContext = extern struct { sp: *anyopaque };
pub const Continuation = *const fn (arg: ?*anyopaque) callconv(.C) noreturn;

// defined in assembly
extern fn fctx_jump(from: *FContext, to: *FContext) callconv(.C) void;
extern fn fctx_trampoline() callconv(.C) void;

// top-level helper to push usize values onto the stack given by sp_addr
fn push64(sp_addr: *usize, value: usize) void {
    sp_addr.* -= 8;
    const p = @as(*usize, @ptrFromInt(sp_addr.*));
    p.* = value;
}

pub fn make(
    stack: []u8,
    entry: Continuation,
    arg: ?*anyopaque,
) FContext {
    // stack grows downward
    var sp: usize = @intFromPtr(stack.ptr) + stack.len;
    sp = std.mem.alignBackward(usize, sp, 16);
    // ret target: need a POINTER first, so take &fctx_trampoline
    const tramp_ptr = &fctx_trampoline;
    push64(&sp, @intFromPtr(tramp_ptr));
    // callee-saved placeholders
    push64(&sp, 0); // rbp
    push64(&sp, 0); // rbx
    push64(&sp, 0); // r12
    push64(&sp, 0); // r13
    // r14 = entry (already a function pointer type)
    push64(&sp, @intFromPtr(entry));
    // r15 = arg (nullable → 0 when null)
    const arg_int: usize = if (arg) |p| @intFromPtr(p) else 0;
    push64(&sp, arg_int);
    return FContext{ .sp = @as(*anyopaque, @ptrFromInt(sp)) };
}

pub inline fn jump(from: *FContext, to: *FContext) void {
    // asm assumes real call since it doesn't save
    // caller-saved registers, only callee-saved registers
    @call(.never_inline, fctx_jump, .{ from, to });
    // fctx_jump(from, to);
}
