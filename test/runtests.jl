using TOMLX
using Test

using Dates
using StaticArrays

function TOMLDict(dict::Dict{Symbol, Any})
    Dict{String, Any}(string(k)=>TOMLDict(dict[k]) for k in keys(dict))
end
TOMLDict(xs::Vector) = [TOMLDict(x) for x in xs]
TOMLDict(x) = x

include("parse.jl")
include("typed_parse.jl")
