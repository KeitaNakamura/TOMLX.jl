@testset "parse" begin
    @testset "string" begin
        dictx = TOMLX.parse(@__MODULE__, """
            str = "hi"
        """)
        @test dictx[:str] == "hi"
    end
    @testset "function" begin
        dictx = TOMLX.parse(@__MODULE__, """
            func = x -> 2x^2
        """)
        @test dictx[:func](3) == 18
    end
    @testset "special characters" begin
        # inf and nan are allowed in julia expression
        dictx = TOMLX.parse(@__MODULE__, """
            x1 = π
            x2 = inf
            x3 = Inf
            x4 = +inf
            x5 = +Inf
            x6 = -inf
            x7 = -Inf
            x8 = nan
            x9 = NaN
            x10 = [π,inf,Inf,+inf,+Inf,-inf,-Inf,nan,NaN]                # wrapped case
            x11 = map(identity, (π,inf,Inf,+inf,+Inf,-inf,-Inf,nan,NaN)) # complex expression
        """)
        @test dictx[:x1] === π
        @test dictx[:x2] === Inf
        @test dictx[:x3] === Inf
        @test dictx[:x4] === Inf
        @test dictx[:x5] === Inf
        @test dictx[:x6] === -Inf
        @test dictx[:x7] === -Inf
        @test dictx[:x8] === NaN
        @test dictx[:x9] === NaN
        @test all(dictx[:x10] .=== (π,Inf,Inf,+Inf,+Inf,-Inf,-Inf,NaN,NaN))
        @test all(dictx[:x11] .=== (π,Inf,Inf,+Inf,+Inf,-Inf,-Inf,NaN,NaN))
    end
    @testset "calculation" begin
        dictx = TOMLX.parse(@__MODULE__, """
            x1 = π * 3
            x2 = 2.0 * 3
            x3 = (1,2,3) .* 2.0
        """)
        @test dictx[:x1] === π * 3
        @test dictx[:x2] === 2.0 * 3
        @test dictx[:x3] === (1,2,3) .* 2.0
    end
    @testset "external package" begin
        dictx = TOMLX.parse(@__MODULE__, """
            x1 = SVector(1,2)
        """)
        @test dictx[:x1] === SVector(1,2)
    end
    @testset "inner table" begin
        dictx = TOMLX.parse(@__MODULE__, """
            tables = [{x=SVector(1.0,2.0), y=SVector(3.0,4.0)}, {x=SVector(5.0,6.0), y=SVector(7.0,8.0)}]
        """)
        @test dictx[:tables] == [Dict{Symbol,Any}(:x=>SVector(1.0,2.0), :y=>SVector(3.0,4.0)),
                                 Dict{Symbol,Any}(:x=>SVector(5.0,6.0), :y=>SVector(7.0,8.0)),]
    end
end

@testset "parsefile" begin
    dict = TOMLX.parsefile("test.toml")
    dict_x = TOMLDict(TOMLX.parsefile(@__MODULE__, "test_x.toml"))
    @test dict_x == dict
end
