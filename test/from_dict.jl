struct MyType{F}
    func::F
    vecs::Vector{SVector{2, Int}}
end
struct MyType_undef_kw{F}
    func::F
    vecs::Vector{SVector{2, Int}}
    val::Int
end
struct MyType_unsupported_kw{F}
    func::F
end
Base.@kwdef struct MyTypeWithKW{F}
    func::F
    vecs::Vector{SVector{2, Int}}
    int::Int = 2
end
Base.@kwdef struct MyTypeWithKW_undef_kw{F}
    func::F
    vecs::Vector{SVector{2, Int}}
    int::Int = 2
    val::Int
end
Base.@kwdef struct MyTypeWithKW_unsupported_kw{F}
    func::F
    int::Int = 2
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

@testset "from_dict" begin
    @testset "single type" begin
        str = """
        func = @jl x -> 2x^2
        vecs = @jl [SVector(1,2), SVector(3,4)]
        """
        @testset "struct" begin
            dict = TOMLX.parse(@__MODULE__, str)
            x = TOMLX.from_dict(MyType, dict)
            @test x isa MyType
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            # errors
            @test_throws TOMLX.UndefFieldError TOMLX.from_dict(MyType_undef_kw, dict)
            @test_throws TOMLX.UnsupportedFieldError TOMLX.from_dict(MyType_unsupported_kw, dict)
        end
        @testset "struct with Base.@kwdef" begin
            dict = TOMLX.parse(@__MODULE__, str)
            x = TOMLX.from_dict(MyTypeWithKW, dict)
            @test x isa MyTypeWithKW
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            @test x.int == 2
            # errors
            @test_throws TOMLX.UndefFieldError TOMLX.from_dict(MyTypeWithKW_undef_kw, dict)
            @test_throws TOMLX.UnsupportedFieldError TOMLX.from_dict(MyTypeWithKW_unsupported_kw, dict)
        end
        @testset "named tuple" begin
            T = @NamedTuple{func::Function, vecs::Vector{SVector{2, Int}}}
            dict = TOMLX.parse(Main, str)
            x = (@inferred TOMLX.from_dict(T, dict))::T
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            # got unsupported keyword
            @test_throws TOMLX.UndefFieldError TOMLX.from_dict(@NamedTuple{func::Function, vecs::Vector{SVector{2, Int}}, val::Int}, dict)
            @test_throws TOMLX.UnsupportedFieldError TOMLX.from_dict(@NamedTuple{func::Function}, dict)
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
            dict = TOMLX.parse(Main, str)
            x = (@inferred TOMLX.from_dict(Parent, dict))::Parent
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
            dict = TOMLX.parse(Main, str)
            x = (TOMLX.from_dict(ParentWithKW, dict))::ParentWithKW{Float64} # cannot infer
            @test x.a == 1.0
            @test x.b == [ChildWithKW(3,"hi",11.0,[2,3]), ChildWithKW(4,"hello",11.0,[1,2])]
            @test x.c == ChildWithKW(c=0,d="0")
            @test x.d === nothing
        end
    end
end
