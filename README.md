# Visidata.jl

A Julia wrapper around [VisiData](https://www.visidata.org/), the terminal spreadsheet multitool.

Visidata and its Python runtime are bundled as a Julia artifact — no separate Python installation required.

## Usage

```julia
using Visidata

visidata("data.csv")                  # open one file
visidata("a.csv", "b.csv")           # open multiple files
visidata_bin()                        # path to the vd executable
```

## Building the artifact

Artifacts are pre-built and committed to `Artifacts.toml`.
Must have permissions to add repo releases, uses `gh`.

```sh
julia scripts/build_artifacts.jl
```
