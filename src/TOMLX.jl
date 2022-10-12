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
        return string("Expr:", value) # wrap
    end
    value
end
preprocess_value_expr!(::Module, x::Symbol) = string("Expr:", x)
preprocess_value_expr!(::Module, x) = x

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

@generated function _parse_typed(::Type{T}, dict::Dict{Symbol}) where {T <: NamedTuple}
    args = map(fieldnames(T), fieldtypes(T)) do name, type
        :(_parse_typed($type, dict[$(QuoteNode(name))]))
    end
    quote
        T(tuple($(args...)))
    end
end

function _parse_typed_kw(::Type{T}, dict::Dict{Symbol}) where {T}
    T(; (k=>_parse_typed(fieldtype(T, k), dict[k]) for k in keys(dict))...)
end

@generated function _parse_typed(::Type{T}, dict::Dict{Symbol}) where {T}
    args = map(fieldnames(T), fieldtypes(T)) do name, type
        :(_parse_typed($type, dict[$(QuoteNode(name))]))
    end
    quote
        try
            _parse_typed_kw(T, dict)
        catch e
            if e isa MethodError
                return T($(args...))
            end
            rethrow()
        end
    end
end

function _parse_typed(::Type{T}, values::Vector) where {Eltype, T <: Vector{Eltype}}
    [_parse_typed(Eltype, val) for val in values]
end
function _parse_typed(::Type{T}, values::Vector) where {T <: Vector} # for UnionAll
    [_parse_typed(T.var.ub, val) for val in values]
end

_parse_typed(::Type{T}, val) where {T} = convert(T, val)

##########
# @kwdef #
##########

# copied from Base (base/util.jl)
# In this version, arguments are `convert`ed implicitly
macro kwdef(expr)
    expr = macroexpand(__module__, expr) # to expand @static
    expr isa Expr && expr.head === :struct || error("Invalid usage of @kwdef")
    expr = expr::Expr
    T = expr.args[2]
    if T isa Expr && T.head === :<:
        T = T.args[1]
    end

    params_ex = Expr(:parameters)
    call_args = Any[]

    _kwdef!(expr.args[3], params_ex.args, call_args)
    # Only define a constructor if the type has fields, otherwise we'll get a stack
    # overflow on construction
    if !isempty(params_ex.args)
        if T isa Symbol
            # call convert
            call_args = map(arg->:(convert(fieldtype($(esc(T)), $(QuoteNode(arg))), $arg)), call_args)
            kwdefs = :(($(esc(T)))($params_ex) = ($(esc(T)))($(call_args...)))
        elseif T isa Expr && T.head === :curly
            T = T::Expr
            # if T == S{A<:AA,B<:BB}, define two methods
            #   S(...) = ...
            #   S{A,B}(...) where {A<:AA,B<:BB} = ...
            S = T.args[1]
            P = T.args[2:end]
            Q = Any[U isa Expr && U.head === :<: ? U.args[1] : U for U in P]
            SQ = :($S{$(Q...)})
            # call convert
            call_args = map(arg->:(convert(fieldtype($(esc(S)), $(QuoteNode(arg))), $arg)), call_args)
            kwdefs = quote
                ($(esc(S)))($params_ex) =($(esc(S)))($(call_args...))
                ($(esc(SQ)))($params_ex) where {$(esc.(P)...)} =
                    ($(esc(SQ)))($(call_args...))
            end
        else
            error("Invalid usage of @kwdef")
        end
    else
        kwdefs = nothing
    end
    quote
        Base.@__doc__($(esc(expr)))
        $kwdefs
    end
end

# @kwdef helper function
# mutates arguments inplace
function _kwdef!(blk, params_args, call_args)
    for i in eachindex(blk.args)
        ei = blk.args[i]
        if ei isa Symbol
            #  var
            push!(params_args, ei)
            push!(call_args, ei)
        elseif ei isa Expr
            is_atomic = ei.head === :atomic
            ei = is_atomic ? first(ei.args) : ei # strip "@atomic" and add it back later
            is_const = ei.head === :const
            ei = is_const ? first(ei.args) : ei # strip "const" and add it back later
            # Note: `@atomic const ..` isn't valid, but reconstruct it anyway to serve a nice error
            if ei isa Symbol
                # const var
                push!(params_args, ei)
                push!(call_args, ei)
            elseif ei.head === :(=)
                lhs = ei.args[1]
                if lhs isa Symbol
                    #  var = defexpr
                    var = lhs
                elseif lhs isa Expr && lhs.head === :(::) && lhs.args[1] isa Symbol
                    #  var::T = defexpr
                    var = lhs.args[1]
                else
                    # something else, e.g. inline inner constructor
                    #   F(...) = ...
                    continue
                end
                defexpr = ei.args[2]  # defexpr
                push!(params_args, Expr(:kw, var, esc(defexpr)))
                push!(call_args, var)
                lhs = is_const ? Expr(:const, lhs) : lhs
                lhs = is_atomic ? Expr(:atomic, lhs) : lhs
                blk.args[i] = lhs # overrides arg
            elseif ei.head === :(::) && ei.args[1] isa Symbol
                # var::Typ
                var = ei.args[1]
                push!(params_args, var)
                push!(call_args, var)
            elseif ei.head === :block
                # can arise with use of @static inside type decl
                _kwdef!(ei, params_args, call_args)
            end
        end
    end
    blk
end

end # module TOMLX
