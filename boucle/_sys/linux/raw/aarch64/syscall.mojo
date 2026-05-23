from std.sys._assembly import inlined_assembly


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
]() -> result_type:
    """Syscall with 0 arguments (aarch64: `svc #0`, nr in x8)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},~{memory}",
            has_side_effect = has_side_effect,
        ](nr)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8}",
            has_side_effect = has_side_effect,
        ](nr)


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
    T0: TrivialRegisterPassable,
](arg0: T0) -> result_type:
    """Syscall with 1 argument (x0)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},~{memory}",
            has_side_effect = has_side_effect,
        ](nr, arg0)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0}",
            has_side_effect = has_side_effect,
        ](nr, arg0)


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
    T0: TrivialRegisterPassable,
    T1: TrivialRegisterPassable,
](arg0: T0, arg1: T1) -> result_type:
    """Syscall with 2 arguments (x0, x1)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},~{memory}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1)


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
    T0: TrivialRegisterPassable,
    T1: TrivialRegisterPassable,
    T2: TrivialRegisterPassable,
](arg0: T0, arg1: T1, arg2: T2) -> result_type:
    """Syscall with 3 arguments (x0, x1, x2)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},~{memory}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2)


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
    T0: TrivialRegisterPassable,
    T1: TrivialRegisterPassable,
    T2: TrivialRegisterPassable,
    T3: TrivialRegisterPassable,
](arg0: T0, arg1: T1, arg2: T2, arg3: T3) -> result_type:
    """Syscall with 4 arguments (x0, x1, x2, x3)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},{x3},~{memory}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2, arg3)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},{x3}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2, arg3)


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
    T0: TrivialRegisterPassable,
    T1: TrivialRegisterPassable,
    T2: TrivialRegisterPassable,
    T3: TrivialRegisterPassable,
    T4: TrivialRegisterPassable,
](arg0: T0, arg1: T1, arg2: T2, arg3: T3, arg4: T4) -> result_type:
    """Syscall with 5 arguments (x0, x1, x2, x3, x4)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},{x3},{x4},~{memory}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2, arg3, arg4)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},{x3},{x4}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2, arg3, arg4)


@always_inline("nodebug")
def syscall[
    nr: UInt64,
    result_type: TrivialRegisterPassable,
    *,
    has_side_effect: Bool = True,
    uses_memory: Bool = True,
    T0: TrivialRegisterPassable,
    T1: TrivialRegisterPassable,
    T2: TrivialRegisterPassable,
    T3: TrivialRegisterPassable,
    T4: TrivialRegisterPassable,
    T5: TrivialRegisterPassable,
](arg0: T0, arg1: T1, arg2: T2, arg3: T3, arg4: T4, arg5: T5) -> result_type:
    """Syscall with 6 arguments (x0, x1, x2, x3, x4, x5)."""

    comptime if uses_memory:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},{x3},{x4},{x5},~{memory}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2, arg3, arg4, arg5)
    else:
        return inlined_assembly[
            "svc #0",
            result_type,
            constraints = "={x0},{x8},{x0},{x1},{x2},{x3},{x4},{x5}",
            has_side_effect = has_side_effect,
        ](nr, arg0, arg1, arg2, arg3, arg4, arg5)
