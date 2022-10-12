using TOMLX
using Test

using TOML
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

@testset "TOMLX" begin
    @testset "parse" begin
        str = """
        func = x -> 2x^2
        vecs = [SVector(1,2), SVector(3,4)]
        """

        @testset "simple parse" begin
            dictx = TOMLX.@parse(str)
            @test dictx[:func](3) == 18
            @test dictx[:vecs] == [SVector(1,2), SVector(3,4)]
        end

        @testset "typed parse" begin
            # struct
            x = TOMLX.@parse(MyType, str)
            @test x isa MyType
            @test x.func(3) == 18
            @test x.vecs == [SVector(1,2), SVector(3,4)]
            # struct with Base.@kwdef
            x = TOMLX.@parse(MyTypeWithKW, str)
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
        dict = TOML.parsefile("test.toml")
        dict_x = TOMLDict(TOMLX.@parsefile("test_x.toml"))
        @test dict_x == dict
    end

    @testset "misc" begin
        # nested julia expression
        str = """
        pts = [{x=SVector(1,2), y=SVector(3,4)}, {x=SVector(5,6), y=SVector(7,8)}]
        num = π
        mul = 2 * 3.0
        """
        dictx = TOMLX.@parse(str)
        @test dictx[:pts] == [Dict{Symbol,Any}(:x=>SVector(1,2), :y=>SVector(3,4)),
                              Dict{Symbol,Any}(:x=>SVector(5,6), :y=>SVector(7,8)),]
        @test dictx[:num] === π
        @test dictx[:mul] === 2 * 3.0
    end
end
