using Base: @pure

const TOMLDict  = Dict{String, Any}

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

#############
# from_dict #
#############

# `from_dict` can be overloaded but `FEOM_DICT` is not

from_dict(::Type{T}, dict::TOMLDict) where {T} = FROM_DICT(T, dict)

# dict -> named tuple
function FROM_DICT(::Type{T}, dict::TOMLDict) where {T <: NamedTuple}
    T(_get_fields(T, dict))
end
# dict -> (mutable) struct
function FROM_DICT(::Type{T}, dict::TOMLDict) where {T}
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

# dict case
_parse(::Type{T}, dict::TOMLDict) where {T} = from_dict(T, dict)
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
function _get_fields(::Type{T}, dict::TOMLDict) where {T}
    names = Iterators.filter(name->!in(name, fieldnames(T)), Iterators.map(Symbol, keys(dict)))
    isempty(names) || throw(UnsupportedFieldError(T, first(names)))
    map(fieldnames(T), fieldtypes(T)) do name, type
        haskey(dict, string(name)) || throw(UndefFieldError(T, name))
        _parse(type, dict[string(name)])
    end
end

## _parse_by_kws
function _parse_by_kws(::Type{T}, dict::TOMLDict) where {T}
    T(; (k=>_parse(_fieldtype(T, k), dict[string(k)]) for k in Iterators.map(Symbol, keys(dict)))...)
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
