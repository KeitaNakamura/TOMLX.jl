using TOML
# parser is defined in Base
using Base.TOML: Parser, parse_value, eat_char, accept, peek, set_marker!, take_substring, EOF_CHAR, ParserError, ErrGenericValueError

using Cassette
Cassette.@context Ctx;

function Cassette.overdub(ctx::Ctx, ::typeof(parse_value), l)
    if accept(l, '@') && accept(l, 'j')
        parse_julia(l, ctx.metadata.mod, ctx.metadata.use_invokelatest)
    else
        Cassette.recurse(ctx, Base.TOML.parse_value, l)
    end
end

function parse_julia(l::Parser, mod::Module, use_invokelatest::Bool)
    err() = ParserError(ErrGenericValueError)
    ok = accept(l, 'l') ||
        (accept(l, 'u') && accept(l, 'l') && accept(l, 'i') && accept(l, 'a'))
    ok || return err()

    if accept(l, ' ')
        ex, p = Meta.parse(l.str, l.prevpos)
        while !(l.pos == p)
            eat_char(l)
        end
    elseif peek(l) === '('
        set_marker!(l)
        eat_char(l)
        count = 0
        while true
            if peek(l) == ')'
                count == 0 && break
                count -= 1
            elseif peek(l) == '('
                count += 1
            end
            eat_char(l)
        end
        eat_char(l)
        ex = Meta.parse(take_substring(l))
    else
        err()
    end

    value = Base.eval(mod, ex)
    if value isa Function && use_invokelatest
        return (args...; kwargs...) -> Base.invokelatest(value, args...; kwargs...)
    end
    value
end

"""
    TOMLX.parse(module, str; use_invokelatest = true)


`TOMLX.parse(module, str)` extends the `TOML.parse(str)` to read Julia expression.
The Julia expression should be specified by `@jl` or `@julia`.
If `use_invokelatest` is `true`, functions are wrapped by `Base.invokelatest` to avoid world age problem.

# Examples

```julia
julia> TOMLX.parse(Main, \"""
       float = 0.1
       udef = @jl undef
       int = @julia begin
           x = 3
           y = 2
           x * y
       end
       numbers = [@jl(π), 3.14]
       \""")
Dict{String, Any} with 4 entries:
  "int"     => 6
  "numbers" => Union{Irrational{:π}, Float64}[π, 3.14]
  "udef"    => UndefInitializer()
  "float"   => 0.1
```
"""
function parse(mod::Module, x::AbstractString; use_invokelatest::Bool=true)
    metadata = (; mod, use_invokelatest)
    Cassette.overdub(Ctx(; metadata), TOML.parse, x)
end

function parsefile(mod::Module, x::AbstractString; use_invokelatest::Bool=true)
    metadata = (; mod, use_invokelatest)
    Cassette.overdub(Ctx(; metadata), TOML.parsefile, x)
end

# original parse
parse(x) = TOML.parse(x)
parsefile(x) = TOML.parsefile(x)
