using ASCIIrasters
using Documenter

DocMeta.setdocmeta!(ASCIIrasters, :DocTestSetup, :(using ASCIIrasters); recursive=true)

makedocs(;
    modules=[ASCIIrasters],
    authors="Josquin Guerber, Rafael Schouten and collaborators",
    repo="https://github.com/JuliaGeo/ASCIIrasters.jl/blob/{commit}{path}#{line}",
    sitename="ASCIIrasters.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jguerber.github.io/ASCIIrasters.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaGeo/ASCIIrasters.jl",
    devbranch="master",
)
