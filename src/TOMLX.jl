module TOMLX

using TOML

readstring(f::AbstractString) = isfile(f) ? read(f, String) : error(repr(f), ": No such file")

parse(mod::Module, x) = postprocess(mod, TOML.parse(preprocess(mod, x)))
parse(mod::Module, ::Type{T}, x) where {T} = _parse_typed(T, parse(mod, x))

parsefile(mod::Module, x) = postprocess(mod, Base.TOML.parse(TOML.Parser(preprocess(mod, readstring(x)); filepath=abspath(x))))
parsefile(mod::Module, ::Type{T}, x) where {T} = _parse_typed(T, parsefile(mod, x))

# macros to omit module
macro parse(args...)
    esc(:($parse($__module__, $(args...))))
end
macro parsefile(args...)
    esc(:($parsefile($__module__, $(args...))))
end

######################
# Pre/Post Processes #
######################

# preprocess
function preprocess(mod::Module, x::String)
    exps = []
    for ex in Meta.parseall(x).args
        ex isa LineNumberNode && continue
        preprocess_entry_expr!(mod, ex)
        push!(exps, ex)
    end
    join(map(string, exps), '\n')
end

function preprocess_entry_expr!(mod::Module, ex::Expr)
    if Meta.isexpr(ex, :(=))
        ex.args[2] = preprocess_value_expr!(mod, ex.args[2])
    else
        for arg in ex.args
            preprocess_entry_expr!(mod, arg)
        end
    end
    ex
end
preprocess_entry_expr!(::Module, ex) = ex

function preprocess_value_expr!(mod::Module, value::Expr)
    if Meta.isexpr(value, :braces) # inner table
        preprocess_entry_expr!(mod, value)
    elseif Meta.isexpr(value, :vect) # vector
        for i in 1:length(value.args)
            value.args[i] = preprocess_value_expr!(mod, value.args[i])
        end
    else
        value isa String || return string("Expr:", value) # wrap
    end
    value
end
preprocess_value_expr!(::Module, ex) = ex

# postprocess
postprocess(mod::Module, dict::Dict{String}) = Dict{Symbol, Any}(Symbol(k)=>postprocess(mod, dict[k]) for k in keys(dict))
postprocess(mod::Module, xs::Vector) = [postprocess(mod, x) for x in xs]
postprocess(mod::Module, x) = postprocess_value(mod, x)
function postprocess_value(mod::Module, x::String) # parse as julia expression if needed
    if startswith(x, "Expr:")
        value = include_string(mod, x[6:end])
        value isa Function && return (args...; kwargs...) -> Base.invokelatest(value, args...; kwargs...)
        value
    else
        x
    end
end
postprocess_value(mod::Module, x) = x

###################
# parse with type #
###################

@generated function _parse_typed(::Type{T}, dict::Dict) where {T <: NamedTuple}
    args = [:(dict[$(QuoteNode(name))]) for name in fieldnames(T)]
    quote
        T(tuple($(args...)))
    end
end

@generated function _parse_typed(::Type{T}, dict::Dict) where {T}
    args = [:(dict[$(QuoteNode(name))]) for name in fieldnames(T)]
    quote
        try
            T(; dict...)
        catch e
            if e isa MethodError
                return T($(args...))
            end
            rethrow()
        end
    end
end

end # module TOMLX
