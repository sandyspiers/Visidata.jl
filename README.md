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

Artifacts are built natively per-platform and committed to `Artifacts.toml`.
To rebuild, bump `VISIDATA_VERSION` in both `scripts/build_platform_artifact.jl`
and `scripts/publish_artifacts.jl`, then trigger the **Build Artifacts** workflow
from the Actions tab. It builds on Linux and Windows runners, publishes a GitHub
Release, and commits the updated `Artifacts.toml` automatically.
