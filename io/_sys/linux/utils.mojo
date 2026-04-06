from sys.info import size_of, align_of


@always_inline("nodebug")
fn _size_eq[T: AnyType, I: AnyType]():
    """Compile-time assertion that two types have the same size."""
    constrained[size_of[T]() == size_of[I]()]()


@always_inline("nodebug")
fn _align_eq[T: AnyType, I: AnyType]():
    """Compile-time assertion that two types have the same alignment."""
    constrained[align_of[T]() == align_of[I]()]()
