const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const Expression = struct {
    obj: *anyopaque,
    applyFn: *const fn (*anyopaque) i32,

    fn init(ptr: anytype) Expression {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);
        if (ptr_info != .pointer) @compileError("ptr must be a pointer");
        if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

        const gen = struct {
            pub fn apply(pointer: *anyopaque) i32 {
                const self: T = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.apply, .{self});
                // return ptr_info.@"pointer".child.apply(self, data);
            }
        };

        return .{
            .obj = ptr,
            .applyFn = gen.apply,
        };
    }

    inline fn apply(self: *const Expression) i32 {
        return self.*.applyFn(self.obj);
    }
};

const Constant = struct {
    value: i32,
    pub fn apply(self: *const Constant) i32 {
        return self.value;
    }

    pub fn create(alloc: Allocator, val: i32) !Expression {
        const mem = try alloc.create(Constant);
        mem.* = .{.value = val };
        return Expression.init(mem);
    }
};

const Add = struct {
    lhs: Expression,
    rhs: Expression,
    pub fn apply(self: *const Add) i32 {
        return self.lhs.apply() + self.rhs.apply();
    }

    pub fn create(alloc: Allocator, lhs: Expression, rhs: Expression) !Expression {
        const mem = try alloc.create(Add);
        mem.* = .{.lhs = lhs, .rhs = rhs};
        return Expression.init(mem);
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    print("Hello World!\n", .{});

    const expr = try Add.create(alloc,
                                try Add.create(alloc,
                                               try Constant.create(alloc, 1),
                                               try Constant.create(alloc, 2)),
                                try Constant.create(alloc, 3));

    const val = expr.apply();

    print("The result is {}\n", .{ val });
}
