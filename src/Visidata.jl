module Visidata

using Artifacts, LazyArtifacts

export visidata_bin, visidata

"""
    visidata_bin() -> String

Return the path to the executable used to launch visidata.
On Unix this is the `vd` shell script; on Windows it is `python.exe`
(invoked as `python.exe -m visidata`).
"""
function visidata_bin()
    art = artifact"visidata"
    bin = if Sys.iswindows()
        joinpath(art, "python.exe")
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
    cmd = if Sys.iswindows()
        `$(visidata_bin()) -m visidata $files`
    else
        `$(visidata_bin()) $files`
    end
    run(cmd)
end

end # module Visidata
