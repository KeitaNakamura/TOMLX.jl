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

Base.@kwdef struct MyType{F}
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

        dictx = TOMLX.@parse(str)
        @test dictx[:func](3) == 18
        @test dictx[:vecs] == [SVector(1,2), SVector(3,4)]

        # typed parse
        x = TOMLX.@parse(MyType, str)
        @test x isa MyType
        @test x.vecs == [SVector(1,2), SVector(3,4)]
        @test x.int == 2

        # nested julia expression
        str = """
        pts = [{x=SVector(1,2), y=SVector(3,4)}, {x=SVector(5,6), y=SVector(7,8)}]
        """
        dictx = TOMLX.@parse(str)
        @test dictx[:pts] == [Dict{Symbol,Any}(:x=>SVector(1,2), :y=>SVector(3,4)),
                              Dict{Symbol,Any}(:x=>SVector(5,6), :y=>SVector(7,8)),]
    end
    @testset "parsefile" begin
        dict = TOML.parsefile("test.toml")
        dict_x = TOMLDict(TOMLX.@parsefile("test_x.toml"))
        @test dict_x == dict
    end
end
