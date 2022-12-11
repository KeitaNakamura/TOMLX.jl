using Documenter
using TOMLX

# Setup for doctests in docstrings
DocMeta.setdocmeta!(TOMLX, :DocTestSetup, recursive = true, :(using TOMLX))

makedocs(;
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    modules = [TOMLX],
    sitename = "TOMLX.jl",
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
    ],
    doctest = true, # :fix
)

deploydocs(
    repo = "github.com/KeitaNakamura/TOMLX.jl.git",
    devbranch = "main",
)
