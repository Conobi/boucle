"""Stackful coroutines via ucontext FFI.

Provides CoroHandle (caller-side) and CoroYielder (coroutine-side)
for cooperative multitasking with real yield/resume semantics.

Linux x86_64 only. Uses POSIX ucontext_t via external_call.
Bridge until Modular ships native waker APIs.
"""

from std.memory import UnsafePointer, memset
from std.memory.unsafe_pointer import alloc
from boucle._sys.linux.ucontext import (
    alloc_ucontext,
    free_ucontext,
    uc_getcontext,
    uc_swapcontext,
    uc_swapcontext_unchecked,
    setup_context,
)
from boucle._sys.linux.mm import (
    mmap_anonymous,
    mprotect,
    MapFlags,
    ProtFlags,
)
from boucle._sys.linux.raw.x86_64.ucontext import PAGE_SIZE
from boucle._sys.linux.raw.x86_64.syscall import syscall
from boucle._sys.linux.raw.x86_64.general import __NR_munmap
from boucle._sys.linux.raw.ctypes import c_void


# Phase constants
comptime CORO_CREATED: UInt8 = 0
comptime CORO_RUNNING: UInt8 = 1
comptime CORO_SUSPENDED: UInt8 = 2
comptime CORO_DONE: UInt8 = 3

# Default stack size (64 KB usable)
comptime DEFAULT_STACK_SIZE: UInt = 65536

# Body function type: receives a mutable CoroYielder, may raise
comptime CoroBody = fn (mut CoroYielder) raises -> None


# ── CoroYielder ──────────────────────────────────────────────────────────


struct CoroYielder:
    """Coroutine-side handle. Passed to the body function.

    Only valid inside the coroutine body -- do not store or
    use after the body returns.
    """

    var _inner: UnsafePointer[_CoroInner, MutExternalOrigin]

    fn __init__(out self, inner: UnsafePointer[_CoroInner, MutExternalOrigin]):
        self._inner = inner

    fn yield_to_caller(mut self):
        """Suspend this coroutine and return control to the caller.

        Execution resumes from here when the caller calls resume().
        """
        self._inner[].phase = CORO_SUSPENDED
        # Unchecked: yield can't raise (no way to propagate from here),
        # and swapcontext only fails with invalid pointers — which would
        # mean _CoroInner is already corrupt. Checking would add overhead
        # on every yield for a condition that indicates unrecoverable state.
        uc_swapcontext_unchecked(
            self._inner[].coro_ctx, self._inner[].caller_ctx
        )
        # When we return here, the caller called resume() again
        self._inner[].phase = CORO_RUNNING

    fn user_data(self) -> UnsafePointer[NoneType, MutExternalOrigin]:
        """Access the user data pointer passed at CoroHandle creation."""
        return self._inner[].user_data


# ── _CoroInner ───────────────────────────────────────────────────────────


struct _CoroInner(Movable):
    """Heap-allocated shared state between CoroHandle and CoroYielder.

    Stable address -- survives CoroHandle moves.
    """

    var caller_ctx: UnsafePointer[UInt8, MutExternalOrigin]
    var coro_ctx: UnsafePointer[UInt8, MutExternalOrigin]
    var stack_base: UnsafePointer[c_void, StaticConstantOrigin]
    var stack_total: UInt
    var phase: UInt8
    var body: CoroBody
    var user_data: UnsafePointer[NoneType, MutExternalOrigin]
    var has_error: Bool
    var error_msg: String

    fn __init__(
        out self,
        body: CoroBody,
        user_data: UnsafePointer[NoneType, MutExternalOrigin],
        stack_base: UnsafePointer[c_void, StaticConstantOrigin],
        stack_total: UInt,
    ):
        self.caller_ctx = alloc_ucontext()
        self.coro_ctx = alloc_ucontext()
        self.stack_base = stack_base
        self.stack_total = stack_total
        self.phase = CORO_CREATED
        self.body = body
        self.user_data = user_data
        self.has_error = False
        self.error_msg = String()

    fn __moveinit__(out self, deinit take: Self):
        self.caller_ctx = take.caller_ctx
        self.coro_ctx = take.coro_ctx
        self.stack_base = take.stack_base
        self.stack_total = take.stack_total
        self.phase = take.phase
        self.body = take.body
        self.user_data = take.user_data
        self.has_error = take.has_error
        self.error_msg = take.error_msg^


# ── Trampoline ───────────────────────────────────────────────────────────


fn _coro_trampoline(inner_addr: Int64):
    """Entry point for new coroutines. Runs on the coroutine stack.

    Receives a pointer to _CoroInner via REG_RDI.
    Calls the user's body function, catches errors, marks DONE, swaps back.
    MUST never return normally -- always swaps back to caller.
    """
    var inner = UnsafePointer[_CoroInner, MutExternalOrigin](
        unsafe_from_address=Int(inner_addr)
    )
    var yielder = CoroYielder(inner)
    try:
        inner[].body(yielder)
    except e:
        inner[].has_error = True
        inner[].error_msg = String(e)
    inner[].phase = CORO_DONE
    uc_swapcontext_unchecked(inner[].coro_ctx, inner[].caller_ctx)
    # Unreachable -- if we get here, the coroutine stack is corrupt.
    # The process will likely crash on the next instruction.


# ── CoroHandle ───────────────────────────────────────────────────────────


struct CoroHandle(Movable):
    """Stackful coroutine. Caller-side handle.

    Lifecycle: CREATED -> RUNNING <-> SUSPENDED -> DONE

    Create with a body function and optional user_data pointer.
    Call resume() to start or continue the coroutine.
    The body calls CoroYielder.yield_to_caller() to suspend.
    """

    var _inner: UnsafePointer[_CoroInner, MutExternalOrigin]

    fn __init__(
        out self,
        body: CoroBody,
        user_data: UnsafePointer[NoneType, MutExternalOrigin] = UnsafePointer[NoneType, MutExternalOrigin](),
        stack_size: UInt = DEFAULT_STACK_SIZE,
    ) raises:
        # Allocate stack: guard page + usable
        var total = UInt(PAGE_SIZE) + stack_size
        var stack_base = mmap_anonymous(
            len=total,
            prot=ProtFlags.READ | ProtFlags.WRITE,
            flags=MapFlags.PRIVATE | MapFlags.STACK,
        )
        try:
            mprotect(
                unsafe_ptr=stack_base,
                len=UInt(PAGE_SIZE),
                prot=ProtFlags.NONE,
            )
        except e:
            # mprotect failed — unmap the stack before propagating
            _ = syscall[__NR_munmap, Scalar[DType.int64]](stack_base, total)
            raise e^

        # Allocate and initialize inner state on heap
        self._inner = alloc[_CoroInner](1)
        self._inner.init_pointee_move(
            _CoroInner(body, user_data, stack_base, total)
        )

        # Set up the coroutine context
        var usable_stack = UnsafePointer[UInt8, MutExternalOrigin](
            unsafe_from_address=Int(stack_base) + PAGE_SIZE
        )
        try:
            uc_getcontext(self._inner[].coro_ctx)

            # Get trampoline function address
            var trampoline_fn = _coro_trampoline
            var fn_addr = Int(
                UnsafePointer(to=trampoline_fn).bitcast[Int]()[]
            )

            setup_context(
                self._inner[].coro_ctx,
                stack_ptr=usable_stack,
                stack_size=stack_size,
                entry_addr=fn_addr,
                arg_addr=Int(self._inner),
            )
        except e:
            # Cleanup inner state if context setup fails
            free_ucontext(self._inner[].caller_ctx)
            free_ucontext(self._inner[].coro_ctx)
            _ = syscall[__NR_munmap, Scalar[DType.int64]](stack_base, total)
            self._inner.destroy_pointee()
            self._inner.free()
            raise e^

    fn __moveinit__(out self, deinit take: Self):
        self._inner = take._inner

    fn __del__(deinit self):
        debug_assert(
            self._inner[].phase == CORO_CREATED
            or self._inner[].phase == CORO_DONE,
            "destroying a coroutine that hasn't finished",
        )
        # Free ucontext buffers
        free_ucontext(self._inner[].caller_ctx)
        free_ucontext(self._inner[].coro_ctx)
        # Unmap stack (non-raising: call syscall directly)
        _ = syscall[__NR_munmap, Scalar[DType.int64]](
            self._inner[].stack_base,
            self._inner[].stack_total,
        )
        # Destroy inner (runs String destructor for error_msg)
        self._inner.destroy_pointee()
        self._inner.free()

    fn resume(mut self) raises:
        """Resume (or start) the coroutine.

        Returns when the body yields or completes.
        Raises if the body raised an error.
        """
        debug_assert(
            self.can_resume(),
            "resume() called on non-resumable coroutine",
        )
        self._inner[].phase = CORO_RUNNING
        uc_swapcontext(
            self._inner[].caller_ctx, self._inner[].coro_ctx
        )
        # We're back -- check for error
        if self._inner[].has_error:
            self._inner[].has_error = False
            raise self._inner[].error_msg

    fn is_done(self) -> Bool:
        """True if the coroutine body has returned or raised."""
        return self._inner[].phase == CORO_DONE

    fn can_resume(self) -> Bool:
        """True if the coroutine can be resumed (CREATED or SUSPENDED)."""
        return (
            self._inner[].phase == CORO_CREATED
            or self._inner[].phase == CORO_SUSPENDED
        )
