using Documenter

push!(LOAD_PATH, "../src/")

using TestContexts

makedocs(
    sitename = "TestContexts.jl",
    modules = [TestContexts],
    authors = "Oren Ben-Kiki",
    clean = true,
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    pages = ["index.md"],
)
