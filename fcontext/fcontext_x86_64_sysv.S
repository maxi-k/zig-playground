// ============================================================================
// Minimal Boost.Context-style switch & trampoline for x86_64 SysV (ELF + GAS)
// ----------------------------------------------------------------------------
// Overview
//  - fctx_jump(from, to):
//      * Saves the current callee-saved registers (rbp, rbx, r12–r15) on the
//        *current* stack.
//      * Stores current %rsp into from->sp (so we can resume later).
//      * Loads %rsp from to->sp (prepared by the Zig code).
//      * Restores callee-saved registers *from the target stack* by popping.
//      * RET: control continues at the return address that was placed on the
//        target stack (we make it point to fctx_trampoline on first entry).
//
//  - fctx_trampoline():
//      * Runs only on the first time we switch into a freshly created context.
//      * Conventions used by our Zig creator:
//          r15 = user argument (void*)
//          r14 = entry function pointer (void (*)(void*) noreturn)
//      * Moves r15 -> rdi (SysV first arg), calls the entry function in r14.
//      * If the entry function returns (it shouldn’t), exit the thread.
//
// ABI notes
//  - SysV x86_64 callee-saved GPRs: rbx, rbp, r12, r13, r14, r15.
//  - We do *not* save caller-saved regs, flags, or FP/SIMD state here.
//  - Stack must be 16-byte aligned *at the point of CALL*. We ensure that in
//    the Zig stack builder; when we RET into the trampoline, alignment matches.
//
// Stack contract for first entry (top of target stack at %rsp on resume):
//    +0   r15  (argument)
//    +8   r14  (entry fn ptr)
//    +16  r13  (dummy)
//    +24  r12  (dummy)
//    +32  rbx  (dummy)
//    +40  rbp  (dummy)
//    +48  RIP  (return address = fctx_trampoline)
//
// After fctx_jump switches %rsp to the target and POPs 6 regs, the remaining
// top is the return address. RET transfers control to fctx_trampoline.
// ============================================================================

    .text
    .globl fctx_jump
    .type  fctx_jump,@function
fctx_jump:
    // --- Save callee-saved regs onto current stack.
    //     This mirrors a normal function prologue but includes r12–r15 and rbx.
    //     The order doesn't matter as long as restore order matches.
    push %rbp
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15
    // ------------------------------------------------------------------------
    // --- Persist current stack pointer into from->sp
    //     FContext is { void* sp; } at offset 0, so [rdi] points to its 'sp'.
    mov  %rsp, (%rdi)
    // --- Switch to target stack: load %rsp from to->sp; now on other stack.
    mov  (%rsi), %rsp
    // ------------------------------------------------------------------------
    // --- Restore callee-saved regs from the target stack, reverse PUSH order
    pop  %r15
    pop  %r14
    pop  %r13
    pop  %r12
    pop  %rbx
    pop  %rbp
    // --- Return to the address found on the target stack.
    //     For first-time entry, Zig arranged it to be fctx_trampoline.
    ret
    .size fctx_jump, .-fctx_jump

// ----------------------------------------------------------------------------
// First-entry trampoline
//
// Contract from Zig stack constructor at first resume:
//   r15 = user arg pointer
//   r14 = entry function pointer (void (*)(void*) noreturn)
// After RET from fctx_jump, RIP = fctx_trampoline.
// ----------------------------------------------------------------------------
    .globl fctx_trampoline
    .type  fctx_trampoline,@function
fctx_trampoline:
    // --- Prepare SysV call: first argument in rdi
    //     Move our out-of-band argument (r15) into rdi.
    mov  %r15, %rdi

    // --- Call the entry function pointer held in r14.
    //     We must go via an indirect call through a register.
    mov  %r14, %rax
    call *%rax

    // The entry function is declared noreturn. If it *does* return, we must
    // not fall back into random memory. Exit the thread instead.
    // --- Exit(0) via Linux syscall if we ever return here.
    //     SysV Linux: rax=60 is SYS_exit, rdi=status.
    xor  %edi, %edi     // status = 0
    mov  $60, %eax      // SYS_exit
    syscall
    // --- If the kernel returns (it shouldn't), HALT.
    hlt
    .size fctx_trampoline, .-fctx_trampoline
