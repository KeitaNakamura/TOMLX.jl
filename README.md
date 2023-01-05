# TOMLX

*Extended TOML parser for Julia expressions*

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://KeitaNakamura.github.io/TOMLX.jl/stable)
[![Build Status](https://github.com/KeitaNakamura/TOMLX.jl/workflows/CI/badge.svg)](https://github.com/KeitaNakamura/TOMLX.jl/actions)
[![codecov](https://codecov.io/gh/KeitaNakamura/TOMLX.jl/branch/main/graph/badge.svg?token=k70humDhCz)](https://codecov.io/gh/KeitaNakamura/TOMLX.jl)

## Installation

```julia
pkg> add https://github.com/KeitaNakamura/TOMLX.jl.git
```

## Usage

`TOMLX.parse(module, str)` extends the `TOML.parse(str)` to read Julia expressions.
The Julia expressions can be specified by `@jl` or `@julia`.

```julia
julia> data = """
       float = 0.1
       udef = @jl undef
       int = @julia let
           x = 3
           y = 2
           x * y
       end
       numbers = [@jl(π), 3.14]
       """;

julia> dict = TOMLX.parse(@__MODULE__, data)
Dict{String, Any} with 4 entries:
  "int"     => 6
  "numbers" => Union{Irrational{:π}, Float64}[π, 3.14]
  "udef"    => UndefInitializer()
  "float"   => 0.1
```

`TOMLX.parsefile(module, str)` is extended as well.

TOMLX.jl also has useful `from_dict` function to construct `struct`s from the parsed dict.

```julia
julia> struct MyType
           float::Float64
           udef::Any
           int::Int
           numbers::Vector{Float64}
       end

julia> TOMLX.from_dict(MyType, dict)
MyType(0.1, UndefInitializer(), 6, [3.141592653589793, 3.14])
```

This function can be used with `Base.@kwdef`.

```julia
julia> Base.@kwdef struct MyTypeWithKW
           float::Float64
           udef::Any
           int::Int                 = 0
           numbers::Vector{Float64}
           name::String             = "Julia"
       end

julia> TOMLX.from_dict(MyTypeWithKW, dict)
MyTypeWithKW(0.1, UndefInitializer(), 6, [3.141592653589793, 3.14], "Julia")
```
