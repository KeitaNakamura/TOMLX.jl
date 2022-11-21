struct MyType{F}
    func::F
    vecs::Vector{SVector{2, Int}}
end
struct MyType_wrong{F}
    func::F
end
Base.@kwdef struct MyTypeWithKW{F}
    func::F
    vecs::Vector{SVector{2, Int}}
    int::Int = 2
end
Base.@kwdef struct MyTypeWithKW_wrong{F}
    func::F
end

struct Child
    c::Int
    d::String
    e::Float64
end
struct Parent
    a::Float64
    b::Vector{Child}
end

Base.@kwdef struct ChildWithKW{U}
    c::Int
    d::String
    e::Float64 = 11.0
    f::Vector{U} = [1,2]
end
Base.:(==)(x::ChildWithKW, y::ChildWithKW) = x.c==y.c && x.d==y.d && x.e==y.e && x.f==y.f
Base.@kwdef struct ParentWithKW{F <: AbstractFloat, C <: ChildWithKW}
    a::F
    b::Vector{C}
    c::ChildWithKW = ChildWithKW(c=0,d="0")
    d::Union{Int, Nothing} = nothing
end

@testset "typed parse" begin
    @testset "single type" begin
        str = """
        func = x -> 2x^2
        vecs = [SVector(1,2), SVector(3,4)]
        """
        @testset "struct" begin
            x = TOMLX.parse(@__MODULE__, MyType, str)
            @test x isa MyType
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            # got unsupported keyword
            @test_throws Exception TOMLX.parse(@__MODULE__, MyType_wrong, str)
        end
        @testset "struct with Base.@kwdef" begin
            x = TOMLX.parse(@__MODULE__, MyTypeWithKW, str)
            @test x isa MyTypeWithKW
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            @test x.int == 2
            # got unsupported keyword
            @test_throws Exception TOMLX.parse(@__MODULE__, MyTypeWithKW_wrong, str)
        end
        @testset "named tuple" begin
            T = @NamedTuple{func::Function, vecs::Vector{SVector{2, Int}}}
            x = (@inferred TOMLX.parse(Main, T, str))::T
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            # got unsupported keyword
            @test_throws Exception TOMLX.parse(Main, @NamedTuple{func::Function}, str)
        end
    end
    @testset "nested type" begin
        @testset "struct" begin
            str = """
            a = 1.0
            [[b]]
            c = 3
            d = "hi"
            e = 10
            [[b]]
            c = 4
            d = "hello"
            e = 12
            """
            x = (@inferred TOMLX.parse(Main, Parent, str))::Parent
            @test x.a == 1.0
            @test x.b == [Child(3,"hi",10), Child(4,"hello",12)]
        end
        @testset "struct with Base.@kwdef" begin
            str = """
            a = 1.0
            [[b]]
            c = 3
            d = "hi"
            f = [2,3]
            [[b]]
            c = 4
            d = "hello"
            """
            x = (TOMLX.parse(Main, ParentWithKW, str))::ParentWithKW{Float64} # cannot infer
            @test x.a == 1.0
            @test x.b == [ChildWithKW(3,"hi",11.0,[2,3]), ChildWithKW(4,"hello",11.0,[1,2])]
            @test x.c == ChildWithKW(c=0,d="0")
            @test x.d === nothing
        end
    end
end
