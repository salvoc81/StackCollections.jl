using Test
using StackCollections

@testset "DigitSet" begin
include("digitset.jl")
end


@testset "StackSet" begin
include("stackset.jl")
end

@testset "OneHotVector" begin
include("onehotvector.jl")
end

@testset "StackVector" begin
include("stackvector.jl")
end
