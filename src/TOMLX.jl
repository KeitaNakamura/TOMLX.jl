module TOMLX

using TOML

readstring(f::AbstractString) = isfile(f) ? read(f, String) : error(repr(f), ": No such file")

parse(mod::Module, x) = postprocess(mod, TOML.parse(preprocess(mod, x)))
parse(mod::Module, ::Type{T}, x) where {T} = _parse2type(T, parse(mod, x))

parsefile(mod::Module, x) = postprocess(mod, Base.TOML.parse(TOML.Parser(preprocess(mod, readstring(x)); filepath=abspath(x))))
parsefile(mod::Module, ::Type{T}, x) where {T} = _parse2type(T, parsefile(mod, x))

# original parse
parse(x) = TOML.parse(x)
parsefile(x) = TOML.parsefile(x)

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
        return preprocess_value_expr(mod, value)
    end
    value
end
preprocess_value_expr!(mod::Module, x::Symbol) = preprocess_value_expr(mod, x)
preprocess_value_expr!(::Module, x) = x

function preprocess_value_expr(mod::Module, x)
    try
        Base.eval(mod, x)
    catch e
        e isa UndefVarError && return x
        rethrow()
    end
    string("Expr:", x) # wrap
end

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

parse(::Type{T}, dict::Dict{Symbol}) where {T} = _parse2type(T, dict)

@generated function _parse2type(::Type{T}, dict::Dict{Symbol}) where {T <: NamedTuple}
    args = map(fieldnames(T), fieldtypes(T)) do name, type
        :(_parse2type($type, dict[$(QuoteNode(name))]))
    end
    quote
        T(tuple($(args...)))
    end
end

_determine_type(::Type{Union{Nothing, T}}) where {T} = T
_determine_type(::Type{Union{Missing, T}}) where {T} = T
function _determine_type(::Type{T}) where {T}
    typeof(T) == Union && error("cannot determine type $T for TOML table")
    T
end
@generated function _parse2type(::Type{FieldType}, dict::Dict{Symbol}) where {FieldType}
    T = _determine_type(FieldType)
    args = map(fieldnames(T), fieldtypes(T)) do name, type
        :(_parse2type($type, dict[$(QuoteNode(name))]))
    end
    quote
        try
            _parse2type_kw($T, dict)
        catch e
            if e isa MethodError
                return $T($(args...))
            end
            rethrow()
        end
    end
end

function _fieldtype(::Type{T}, k::Symbol) where {T}
    k in fieldnames(T) ? fieldtype(T, k) : Any
end
function _parse2type_kw(::Type{T}, dict::Dict{Symbol}) where {T}
    T(; (k=>_parse2type(_fieldtype(T, k), dict[k]) for k in keys(dict))...)
end

function _parse2type(::Type{T}, values::Vector) where {Eltype, T <: Vector{Eltype}}
    [_parse2type(Eltype, val) for val in values]
end
function _parse2type(::Type{T}, values::Vector) where {T <: Vector} # for UnionAll
    [_parse2type(T.var.ub, val) for val in values]
end

_parse2type(::Type{T}, val) where {T} = val

end # module TOMLX
