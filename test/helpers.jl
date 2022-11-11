@testset "helper functions" begin
    # values
    @test TOMLX.preprocess_value_expr!(:(SVector(inf))) == "Expr:SVector(Inf)"
    @test TOMLX.preprocess_value_expr!(:(SVector(+inf))) == "Expr:SVector(+Inf)"
    @test TOMLX.preprocess_value_expr!(:(SVector(-inf))) == "Expr:SVector(-Inf)"
    @test TOMLX.preprocess_value_expr!(:(SVector(nan))) == "Expr:SVector(NaN)"
    @test TOMLX.preprocess_value_expr!(:("hello")) == "hello"
    # inner table
    @test TOMLX.preprocess_value_expr!(:({a=1, b=π, c="hi"})) == :({a="Expr:1", b="Expr:π", c="hi"})
    @test TOMLX.preprocess_value_expr!(:({a.b=1, a.c=π, a.d="hi"})) == :({a.b="Expr:1", a.c="Expr:π", a.d="hi"})
    # vector
    @test TOMLX.preprocess_value_expr!(:([1, π, "hi"])) == :(["Expr:1", "Expr:π", "hi"])
    @test TOMLX.preprocess_value_expr!(:([{a=1,b="hi"},{a=2,b="yeah"}])) == :([{a="Expr:1",b="hi"},{a="Expr:2",b="yeah"}])
    # braces
    @test TOMLX.preprocess_value_expr!(:(Tuple{Int, Float64})) == "Expr:Tuple{Int, Float64}"
    # macro
    @test TOMLX.postprocess_value(Main, TOMLX.preprocess_value_expr!(:(@NamedTuple{a::Float64,b::Int}))) == NamedTuple{(:a, :b), Tuple{Float64, Int64}}
end
