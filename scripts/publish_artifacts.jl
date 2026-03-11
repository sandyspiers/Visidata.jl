# Publishes visidata artifacts to a GitHub Release and writes Artifacts.toml.
# Run after both platform build jobs have completed (from repo root):
#   julia scripts/publish_artifacts.jl

using Pkg.Artifacts
using TOML

const VISIDATA_VERSION = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["visidata"]["version"]
const TAG           = "v$VISIDATA_VERSION"
const REPO          = "sandyspiers/Visidata.jl"
const ARTIFACT_TOML = joinpath(@__DIR__, "..", "Artifacts.toml")

# artifacts/ is populated by actions/download-artifact in the workflow:
#   artifacts/tarball-linux/   — visidata-linux-x86_64.tar.gz, tree-hash.txt, sha256.txt
#   artifacts/tarball-windows/ — visidata-windows-x86_64.tar.gz, tree-hash.txt, sha256.txt

println("==> Creating GitHub Release $TAG")
success(`gh release delete $TAG --repo $REPO --yes --cleanup-tag`)
run(`gh release create $TAG --repo $REPO --title "visidata $VISIDATA_VERSION" --notes "Bundled visidata $VISIDATA_VERSION artifact."`)
run(`gh release upload $TAG $(["artifacts/tarball-$p/visidata-$p-x86_64.tar.gz" for p in ("linux","windows")]) --repo $REPO`)

println("==> Writing Artifacts.toml")
for (platform, os, extra) in [("linux", "linux", Dict(:libc => "glibc")), ("windows", "windows", Dict())]
    dir  = "artifacts/tarball-$platform"
    hash = Base.SHA1(hex2bytes(strip(read("$dir/tree-hash.txt", String))))
    sha2 = strip(read("$dir/sha256.txt", String))
    url  = "https://github.com/$REPO/releases/download/$TAG/visidata-$platform-x86_64.tar.gz"
    plat = Base.BinaryPlatforms.Platform("x86_64", os; extra...)
    bind_artifact!(ARTIFACT_TOML, "visidata", hash;
        platform=plat, download_info=[(url, sha2)], lazy=false, force=true)
    println("  $platform: $url  [$sha2]")
end
