@testset "parse" begin
    parse(str) = TOMLX.parse(@__MODULE__, str)
    @testset "string" begin
        dictx = """
            str = "hi"
        """ |> parse
        @test dictx["str"] == "hi"
    end
    @testset "function" begin
        dictx = """
            func = @jl x -> 2x^2
        """ |> parse
        @test dictx["func"](3) == 18
    end
    @testset "special characters" begin
        # inf and nan are allowed in julia expression
        dictx = """
            x1 = @jl π
            x2 = inf
            x3 = @jl Inf
            x4 = +inf
            x5 = @jl +Inf
            x6 = -inf
            x7 = @jl -Inf
            x8 = nan
            x9 = @jl NaN
            x10 = [@jl(π),inf,@jl(Inf),+inf,@jl(+Inf),-inf,@jl(-Inf),nan,@jl(NaN)] # wrapped case
        """ |> parse
        @test dictx["x1"] === π
        @test dictx["x2"] === Inf
        @test dictx["x3"] === Inf
        @test dictx["x4"] === Inf
        @test dictx["x5"] === Inf
        @test dictx["x6"] === -Inf
        @test dictx["x7"] === -Inf
        @test dictx["x8"] === NaN
        @test dictx["x9"] === NaN
        @test all(dictx["x10"] .=== (π,Inf,Inf,+Inf,+Inf,-Inf,-Inf,NaN,NaN))
    end
    @testset "calculation" begin
        dictx = """
            x1 = @jl π * 3
            x2 = @jl 2.0 * 3
            x3 = @jl (1,2,3) .* 2.0
        """ |> parse
        @test dictx["x1"] === π * 3
        @test dictx["x2"] === 2.0 * 3
        @test dictx["x3"] === (1,2,3) .* 2.0
    end
    @testset "external package" begin
        dictx = """
            x1 = @jl SVector(1,2)
        """ |> parse
        @test dictx["x1"] === SVector(1,2)
    end
    @testset "inner table" begin
        dictx = """
            tables = [{x=@jl(SVector(1.0,2.0)), y=@jl(SVector(3.0,4.0))}, {x=@jl(SVector(5.0,6.0)), y=@jl(SVector(7.0,8.0))}]
        """ |> parse
        @test dictx["tables"] == [Dict{String,Any}("x"=>SVector(1.0,2.0), "y"=>SVector(3.0,4.0)),
                                  Dict{String,Any}("x"=>SVector(5.0,6.0), "y"=>SVector(7.0,8.0)),]
    end
    @testset "dots" begin
        dictx = """
            a.b = 1
            a.c = "hello"
            a.d = @jl π
        """ |> parse
        @test dictx["a"]["b"] === 1
        @test dictx["a"]["c"] == "hello"
        @test dictx["a"]["d"] === π
    end
    @testset "check new line" begin
        @test TOMLX.parse(@__MODULE__, "x = @jl (3,2)")["x"] === (3,2)
        @test TOMLX.parse(@__MODULE__, "x = @jl (3,2)\n")["x"] === (3,2)
        @test TOMLX.parse(@__MODULE__, """
            x = @jl (3,2)
            y = 3
        """)["x"] === (3,2)
        @test TOMLX.parse(@__MODULE__, "x = @jl(3,2)")["x"] === (3,2)
        @test TOMLX.parse(@__MODULE__, "x = @jl(3,2)\n")["x"] === (3,2)
        @test TOMLX.parse(@__MODULE__, """
            x = @jl(3,2)
            y = 3
        """)["x"] === (3,2)
    end
end

@testset "parsefile" begin
    dict = TOMLX.parsefile("tomlfiles/test.toml")
    dict_x = TOMLX.parsefile(@__MODULE__, "tomlfiles/test_x.toml")
    @test dict_x == dict
end
