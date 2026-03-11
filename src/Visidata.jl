module Visidata

using Artifacts

export visidata_bin, visidata

"""
    visidata_bin() -> String

Return the path to the visidata launcher from the artifact.
On Unix this is `bin/vd`; on Windows it is `Scripts/vd.bat`.
"""
function visidata_bin()
    art = artifact"visidata"
    bin = if Sys.iswindows()
        joinpath(art, "Scripts", "vd.bat")
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
    bin = visidata_bin()
    if Sys.iswindows()
        run(`cmd /c $bin $files`)
    else
        run(`$bin $files`)
    end
end

end # module Visidata
