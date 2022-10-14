using TOMLX
using Test

using Dates
using StaticArrays

function TOMLDict(dict::Dict{Symbol, Any})
    Dict{String, Any}(string(k)=>TOMLDict(dict[k]) for k in keys(dict))
end
TOMLDict(xs::Vector) = [TOMLDict(x) for x in xs]
TOMLDict(x) = x

struct MyType{F}
    func::F
    vecs::Vector{SVector{2, Int}}
end
Base.@kwdef struct MyTypeWithKW{F}
    func::F
    vecs::Vector{SVector{2, Int}}
    int::Int = 2
end

abstract type AbstractFoo end
struct Foo <: AbstractFoo
    x::Float64
end
Base.convert(::Type{AbstractFoo}, x::Number) = Foo(x)

struct Child{T <: AbstractFoo}
    c::Int
    d::String
    e::T
    Child(c,d,e::T) where {T<:AbstractFoo} = new{T}(c,d,e)
    Child(c,d,e) = Child(c,d,convert(AbstractFoo,e))
end
struct Parent
    a::Float64
    b::Vector{Child}
end

Base.@kwdef struct ChildWithKW{T <: AbstractFoo, U}
    c::Int
    d::String
    e::T = 11 # converted to Foo in inner constructor
    f::Vector{U} = [1,2]
    ChildWithKW(c,d,e::T,f::Vector{U}) where {T<:AbstractFoo,U} = new{T,U}(c,d,e,f)
    ChildWithKW(c,d,e,f) = ChildWithKW(c,d,convert(AbstractFoo,e),f)
end
Base.:(==)(x::ChildWithKW, y::ChildWithKW) = x.c==y.c && x.d==y.d && x.e==y.e && x.f==y.f
Base.@kwdef struct ParentWithKW{F <: AbstractFloat, C <: ChildWithKW}
    a::F
    b::Vector{C}
    c::ChildWithKW = ChildWithKW(c=0,d="0")
    d::Union{Foo, Nothing} = nothing
end

@testset "TOMLX" begin
    @testset "parse" begin
        str = """
        func = x -> 2x^2
        vecs = [SVector(1,2), SVector(3,4)]
        """

        @testset "simple parse" begin
            dictx = TOMLX.parse(@__MODULE__, str)
            @test dictx[:func](3) == 18
            @test dictx[:vecs] == [SVector(1,2), SVector(3,4)]
        end

        @testset "typed parse" begin
            # struct
            x = TOMLX.parse(@__MODULE__, MyType, str)
            @test x isa MyType
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            # struct with Base.@kwdef
            x = TOMLX.parse(@__MODULE__, MyTypeWithKW, str)
            @test x isa MyTypeWithKW
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            @test x.int == 2
            # NamedTuple
            T = @NamedTuple{func::Function, vecs::Vector{SVector{2, Int}}}
            x = (@inferred TOMLX.parse(Main, T, str))::T
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
        end
    end

    @testset "parsefile" begin
        dict = TOMLX.parsefile("test.toml")
        dict_x = TOMLDict(TOMLX.parsefile(@__MODULE__, "test_x.toml"))
        @test dict_x == dict
    end

    @testset "misc" begin
        # nested julia expression
        str = """
        pts = [{x=SVector(1,2), y=SVector(3,4)}, {x=SVector(5,6), y=SVector(7,8)}]
        num = π
        mul = 2 * 3.0
        """
        dictx = TOMLX.parse(@__MODULE__, str)
        @test dictx[:pts] == [Dict{Symbol,Any}(:x=>SVector(1,2), :y=>SVector(3,4)),
                              Dict{Symbol,Any}(:x=>SVector(5,6), :y=>SVector(7,8)),]
        @test dictx[:num] === π
        @test dictx[:mul] === 2 * 3.0

        # nested types
        str = """
        a = 1.0
        [[b]]
        c = 3
        d = "hi"
        e = 10 # converted to Foo in inner constructor
        [[b]]
        c = 4
        d = "hello"
        e = 12 # converted to Foo in inner constructor
        """
        x = (@inferred TOMLX.parse(Main, Parent, str))::Parent
        @test x.a == 1.0
        @test x.b == [Child(3,"hi",Foo(10)), Child(4,"hello",Foo(12))]

        # nested types with kw
        str = """
        a = 1.0
        [[b]]
        c = 3
        d = "hi"
        f = [2,3]
        [[b]]
        c = 4
        d = "hello"
        [d]
        x = 10
        """
        x = (TOMLX.parse(Main, ParentWithKW, str))::ParentWithKW{Float64} # cannot infer
        @test x.a == 1.0
        @test x.b == [ChildWithKW(3,"hi",Foo(11),[2,3]), ChildWithKW(4,"hello",Foo(11),[1,2])]
        @test x.c == ChildWithKW(c=0,d="0")
        @test x.d == Foo(10)
    end
end
