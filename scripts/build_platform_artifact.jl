# Builds the visidata artifact for the CURRENT platform and archives it to
# scripts/output/. Intended to run inside a CI matrix job (linux + windows)
# so each platform is built natively — no cross-compilation.
#
# Outputs (to GITHUB_OUTPUT if available, and stdout):
#   tree-hash  — git-tree-sha1 of the artifact
#   sha256     — sha256 of the tarball
#
# Usage:
#   julia scripts/build_platform_artifact.jl

using Pkg.Artifacts
using Downloads: download
using SHA

# ── Config ────────────────────────────────────────────────────────────────────

const VISIDATA_VERSION = "3.1.1"   # ← bump this to upgrade

const PYTHON_URLS = Dict(
    "linux"   => "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz",
    "windows" => "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-x86_64-pc-windows-msvc-install_only_stripped.tar.gz",
)

const PLATFORM   = Sys.iswindows() ? "windows" : "linux"
const OUT_DIR    = joinpath(@__DIR__, "output")
const TARBALL    = joinpath(OUT_DIR, "visidata-$PLATFORM-x86_64.tar.gz")

# ── Build ─────────────────────────────────────────────────────────────────────

function build()
    url     = PYTHON_URLS[PLATFORM]
    archive = "cpython-$PLATFORM.tar.gz"

    hash = create_artifact() do dir
        println("  Downloading Python ($PLATFORM)")
        download(url, archive)
        println("  Extracting")
        run(`tar -xzf $archive -C $dir --strip-components=1`)
        rm(archive)

        if Sys.iswindows()
            python = joinpath(dir, "python.exe")
            println("  pip install visidata==$VISIDATA_VERSION")
            run(`$python -m pip install --no-cache-dir visidata==$VISIDATA_VERSION`)
        else
            pip = joinpath(dir, "bin", "pip3")
            println("  pip install visidata==$VISIDATA_VERSION")
            run(`$pip install --no-cache-dir visidata==$VISIDATA_VERSION`)

            # Fix the pip-generated shebang — it hardcodes the temporary
            # build-time artifact path, which won't exist at runtime.
            vd = joinpath(dir, "bin", "vd")
            @assert isfile(vd)
            write(vd, "#!/bin/sh\nexec \"\$(dirname \"\$0\")/python3.13\" -m visidata \"\$@\"\n")
            chmod(vd, 0o755)
        end
    end

    return hash
end

# ── Main ──────────────────────────────────────────────────────────────────────

println("==> Building $PLATFORM artifact  (visidata $VISIDATA_VERSION)")
mkpath(OUT_DIR)

hash         = build()
tree_hash    = bytes2hex(hash.bytes)

println("==> Archiving to $TARBALL")
archive_artifact(hash, TARBALL)

sha256_hex = open(io -> bytes2hex(sha256(io)), TARBALL)

println("tree-hash: $tree_hash")
println("sha256:    $sha256_hex")

# Write outputs for GitHub Actions
if haskey(ENV, "GITHUB_OUTPUT")
    open(ENV["GITHUB_OUTPUT"], "a") do io
        println(io, "tree-hash=$tree_hash")
        println(io, "sha256=$sha256_hex")
    end
end

# Save alongside the tarball so the publish job can read them without
# relying on GitHub Actions inter-job outputs.
write(joinpath(OUT_DIR, "tree-hash.txt"), tree_hash)
write(joinpath(OUT_DIR, "sha256.txt"),    sha256_hex)
