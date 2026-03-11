# Publishes visidata artifacts to a GitHub Release and writes Artifacts.toml.
# Run after both platform build jobs have completed and their outputs have been
# downloaded into the working directory by actions/download-artifact.
#
# Expected directory layout (created by download-artifact with path: artifacts/):
#   artifacts/
#     tarball-linux/
#       visidata-linux-x86_64.tar.gz
#       tree-hash.txt
#       sha256.txt
#     tarball-windows/
#       visidata-windows-x86_64.tar.gz
#       tree-hash.txt
#       sha256.txt
#
# Usage (from repo root):
#   julia scripts/publish_artifacts.jl

using Pkg.Artifacts

const VISIDATA_VERSION = "3.1.1"   # ← keep in sync with build_platform_artifact.jl
const TAG           = "v$VISIDATA_VERSION"
const REPO          = "sandyspiers/Visidata.jl"
const ARTIFACT_NAME = "visidata"
const ARTIFACT_TOML = joinpath(@__DIR__, "..", "Artifacts.toml")

# ── Read build outputs ────────────────────────────────────────────────────────

struct PlatformArtifact
    platform  :: String
    tarball   :: String
    tree_hash :: Base.SHA1
    sha256    :: String
    url       :: String
end

function load_platform(platform)
    dir      = joinpath("artifacts", "tarball-$platform")
    tarball  = joinpath(dir, "visidata-$platform-x86_64.tar.gz")
    tree_hash = Base.SHA1(hex2bytes(strip(read(joinpath(dir, "tree-hash.txt"), String))))
    sha256    = strip(read(joinpath(dir, "sha256.txt"), String))
    url       = "https://github.com/$REPO/releases/download/$TAG/visidata-$platform-x86_64.tar.gz"
    return PlatformArtifact(platform, tarball, tree_hash, sha256, url)
end

platforms = [load_platform("linux"), load_platform("windows")]

# ── GitHub Release ────────────────────────────────────────────────────────────

println("==> Creating GitHub Release $TAG")
success(`gh release delete $TAG --repo $REPO --yes --cleanup-tag`)
run(`gh release create $TAG --repo $REPO --title "visidata $VISIDATA_VERSION" --notes "Bundled visidata $VISIDATA_VERSION artifact."`)

tarballs = [p.tarball for p in platforms]
run(`gh release upload $TAG $tarballs --repo $REPO`)

# ── Artifacts.toml ────────────────────────────────────────────────────────────

println("==> Writing Artifacts.toml")

platform_map = Dict(
    "linux"   => Base.BinaryPlatforms.Platform("x86_64", "linux"),
    "windows" => Base.BinaryPlatforms.Platform("x86_64", "windows"),
)

for p in platforms
    bind_artifact!(ARTIFACT_TOML, ARTIFACT_NAME, p.tree_hash;
        platform      = platform_map[p.platform],
        download_info = [(p.url, p.sha256)],
        lazy          = true,
        force         = true)
    println("  $(p.platform): $(p.url)  [$(p.sha256)]")
end

println("\nDone. Commit Artifacts.toml and push.")
