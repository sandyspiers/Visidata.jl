module Visidata

using Artifacts, LazyArtifacts

export visidata_bin, visidata

"""
    visidata_bin() -> String

Return the path to the `vd` executable from the visidata artifact.
On Unix this is `bin/vd`; on Windows it is `Scripts/vd.exe`, the console
entry point created by pip — the same executable visidata installs normally.
"""
function visidata_bin()
    art = artifact"visidata"
    bin = if Sys.iswindows()
        joinpath(art, "Scripts", "vd.exe")
    else
        joinpath(art, "bin", "vd")
    end
    isfile(bin) || error("visidata binary not found at $bin")
    return bin
end

"""
    visidata(files...)

Launch visidata with the given file paths.
"""
function visidata(files...)
    run(`$(visidata_bin()) $files`)
end

end # module Visidata
