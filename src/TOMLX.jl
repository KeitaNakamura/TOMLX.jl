module TOMLX

using TOML
using Base: @pure

# TOML table
const Table = Union{Dict{String}, Dict{Symbol}}

readstring(f::AbstractString) = isfile(f) ? read(f, String) : error(repr(f), ": No such file")

# extended parse
parse(mod::Module, x) = postprocess(mod, TOML.parse(preprocess(x)))
parsefile(mod::Module, x) = postprocess(mod, Base.TOML.parse(TOML.Parser(preprocess(readstring(x)); filepath=abspath(x))))

# original parse
parse(x) = TOML.parse(x)
parsefile(x) = TOML.parsefile(x)

##########
# Errors #
##########

abstract type FieldError <: Exception end

struct UndefFieldError <: FieldError
    type::Type
    name::Symbol
end
function Base.showerror(io::IO, e::UndefFieldError)
    print(io, "UndefFieldError: ")
    print(io, "field \"", e.name, "\" must be given for type \"", e.type, "\"")
end

struct UnsupportedFieldError <: FieldError
    type::Type
    name::Symbol
end
function Base.showerror(io::IO, e::UnsupportedFieldError)
    print(io, "UnsupportedFieldError: ")
    print(io, "got unsupported field \"", e.name, "\" for type \"", e.type, "\"")
end

######################
# Pre/Post Processes #
######################

# preprocess
function preprocess(x::String)
    exps = []
    for ex in Meta.parseall(x).args
        preprocess_entry_expr!(ex)
        push!(exps, ex)
    end
    join(map(string, exps), '\n')
end

# parse tables
function preprocess_entry_expr!(ex::Expr)
    if Meta.isexpr(ex, :(=))
        ex.args[2] = preprocess_value_expr!(ex.args[2])
    else
        for arg in ex.args
            preprocess_entry_expr!(arg)
        end
    end
    ex
end
preprocess_entry_expr!(ex) = ex

# parse value as julia expression
function preprocess_value_expr!(value::Expr)
    if Meta.isexpr(value, :braces) # inner table
        preprocess_entry_expr!(value)
    elseif Meta.isexpr(value, :vect) # vector
        for i in 1:length(value.args)
            value.args[i] = preprocess_value_expr!(value.args[i])
        end
    else
        return preprocess_julia_expr!(value)
    end
    value
end
preprocess_value_expr!(str::String) = str
preprocess_value_expr!(x) = preprocess_julia_expr!(x)

# replace some non-julian expression in `expr`, and wrap it for `postprocess`
function preprocess_julia_expr!(expr)
    string("Expr:", replace_to_julia_expr!(expr)) # wrap
end
function replace_to_julia_expr!(expr::Expr)
    for i in 1:length(expr.args)
        expr.args[i] = replace_to_julia_expr!(expr.args[i])
    end
    expr
end
function replace_to_julia_expr!(sym::Symbol)
    sym === :inf && return :Inf
    sym === :nan && return :NaN
    sym
end
replace_to_julia_expr!(x) = x

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

#############
# from_dict #
#############

from_dict(::Type{T}, dict::Table) where {T} = _parse(T, dict)

# dict -> named tuple
function _parse(::Type{T}, dict::Table) where {T <: NamedTuple}
    T(_get_fields(T, dict))
end
# dict -> (mutable) struct
function _parse(::Type{T}, dict::Table) where {T}
    U = _determine_type(T)
    try
        # try calling constructor by keyword arguments
        _parse_by_kws(U, dict)
    catch e
        if e isa UndefKeywordError
            # In this case, constructor with keyword arguments is defined,
            # but given keywords were wrong, so throw UndefKeywordError.
            throw(UndefFieldError(T, e.var))
        end
        if e isa MethodError
            # Constructor with keyword arguments is NOT defined or unsupported keyword argument is given,
            # so try calling normal constructor by simply giving fields as arguments.
            # Unsupported keyword argument can be detected in `_get_fields` function.
            # Be careful that the UnsupportedFieldError should be checked first rather than UndefKeywordError in `_get_fields` function
            # to handle the case that the constructor with keyword arguments are defined but given keyword arguments are not supported.
            return U(_get_fields(U, dict)...)
        end
        rethrow()
    end
end
# vector cases
function _parse(::Type{T}, values::Vector) where {Eltype, T <: Vector{Eltype}}
    [_parse(Eltype, val) for val in values]
end
function _parse(::Type{T}, values::Vector) where {T <: Vector} # for UnionAll
    [_parse(T.var.ub, val) for val in values]
end
# others
_parse(::Type{T}, val) where {T} = convert(T, val)

## _get_fields
function _get_fields(::Type{T}, dict::Dict{Symbol}) where {T}
    names = filter(name->!in(name, fieldnames(T)), keys(dict))
    isempty(names) || throw(UnsupportedFieldError(T, first(names)))
    map(fieldnames(T), fieldtypes(T)) do name, type
        haskey(dict, name) || throw(UndefFieldError(T, name))
        _parse(type, dict[name])
    end
end
function _get_fields(::Type{T}, dict::Dict{String}) where {T}
    _get_fields(T, Dict(zip(Iterators.map(Symbol, keys(dict)), values(dict))))
end

## _parse_by_kws
function _parse_by_kws(::Type{T}, dict::Table) where {T}
    T(; (k=>_parse(_fieldtype(T, k), dict[k]) for k in keys(dict))...)
end

## _determine_type
@pure _determine_type(::Type{Union{Nothing, T}}) where {T} = T
@pure _determine_type(::Type{Union{Missing, T}}) where {T} = T
@pure function _determine_type(::Type{T}) where {T}
    typeof(T) == Union && error("cannot determine type $T for TOML table")
    T
end

## _fieldtype
function _fieldtype(::Type{T}, k::Symbol) where {T}
    k in fieldnames(T) ? fieldtype(T, k) : Any
end

end # module TOMLX
