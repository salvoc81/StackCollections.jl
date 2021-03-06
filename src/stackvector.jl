struct StackVector{L} <: AbstractVector{Bool}
    x::UInt

    function StackVector{L}(x::UInt, ::Unsafe) where L
        L isa Int || throw(TypeError(:StackVector, "", Int, typeof(L)))
        ((L ≤ Sys.WORD_SIZE) & (L > -1)) || throw(DomainError(L, "L must be 0:$(Sys.WORD_SIZE)"))
        new(x)
    end
end

mask(L) = UInt(1) << L - 1
Base.size(s::StackVector) = (length(s),)
Base.length(s::StackVector{L}) where L = L

function Base.hash(x::StackVector{L}, h::UInt) where L
    base = (0x93774c8a392b33bb % UInt) * L
    h = hash(base, h)
    return hash(x.x, h)
end

StackVector{L}() where L = StackVector{L}(UInt(0), unsafe)
StackVector(x...) = StackVector{Sys.WORD_SIZE}(x...)
@noinline function toofew(L)
    throw(ArgumentError("StackVector{$L} must be constructed from $L elements"))
end

function StackVector{L}(itr) where L
    bits = zero(UInt)
    index = 0
    for i in itr
        index += 1
        index > L && throw(BoundsError(StackVector{L}(), index))
        val = convert(UInt, convert(Bool, i))
        bits |= (val << ((index-1) & 63))
    end
    index == L || toofew(L)
    StackVector{L}(bits, unsafe)
end

function Base.getindex(s::StackVector, i::Int)
    @boundscheck checkbounds(s, i)
    return isodd(s.x >>> unsigned(i-1))
end

function setindex(s::StackVector, v::Bool, i::Int)
    @boundscheck checkbounds(s, i)
    u = UInt(1) << ((i-1) & 63)
    typeof(s)(ifelse(v, s.x | u, s.x & ~u), unsafe)
end

function Base.iterate(s::StackVector, i::Int=0)
    i+1 > length(s) && return nothing
    isodd(s.x >>> (i&63)), i+1
end

Base.in(v::Bool, s::StackVector{L}) where L = !iszero(ifelse(v, s.x, s.x ⊻ mask(L)))
Base.isempty(s::StackVector{L}) where L = iszero(L)

Base.maximum(s::StackVector) = !minimum(!s)
function Base.minimum(s::StackVector{L}) where L
    isempty(s) && throw(ArgumentError("cannot take minimum of empty collection"))
    return s.x == mask(L)
end

Base.sum(s::StackVector) = count_ones(s.x)

function Base.convert(::Type{BitVector}, s::StackVector)
    b = BitVector(undef, length(s))
    !isempty(s) && @inbounds b.chunks[1] = s.x
    b
end

Base.:!(s::StackVector{L}) where L = StackVector{L}(s.x ⊻ mask(L), unsafe)

function Base.filter(f::Function, s::StackVector{L}) where L
    ft::Bool = f(true)
    ff::Bool = f(false)
    ft & ff && return typeof(s)(mask(L), unsafe)
    !(ft | ff) && return typeof(s)(zero(UInt), unsafe)
    ff && return !s
    return s
end

function Base.findfirst(s::StackVector{L}) where L
    isempty(s) && return nothing
    i = trailing_zeros(s.x) + 1
    i > L && return nothing
    return i
end

function Base.findfirst(f::Function, s::StackVector{L}) where L
    isempty(s) && return nothing
    ft::Bool = f(true)
    ff::Bool = f(false)
    ft & ff && return 1
    !(ft | ff) && return nothing
    return findfirst(ifelse(ft, s, !s))
end

Base.argmin(s::StackVector) = argmax(!s)
function Base.argmax(s::StackVector)
    isempty(s) && throw(ArgumentError("collection must be non-empty"))
    f = findfirst(s)
    return f === nothing ? 1 : f
end

function Base.reverse(s::StackVector)
    x = s.x
    x = ((x & 0xaaaaaaaaaaaaaaaa) >>> 1)  | ((x & 0x5555555555555555) << 1)
    x = ((x & 0xcccccccccccccccc) >>> 2)  | ((x & 0x3333333333333333) << 2)
    x = ((x & 0xf0f0f0f0f0f0f0f0) >>> 4)  | ((x & 0x0f0f0f0f0f0f0f0f) << 4)
    x = bswap(x)
    x >>>= sizeof(UInt) << 3 - length(s)
    typeof(s)(x, unsafe)
end

function Base.circshift(s::StackVector{L}, k::Int) where L
    iszero(L) && return s
    shift = abs(k) % L
    left = ifelse(k < 0, L+k, k) & 63
    right = (L - left) & 63
    bits = ((s.x << left) | (s.x >>> right)) & mask(L)
    return StackVector{L}(bits, unsafe)
end
