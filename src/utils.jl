"""
    HDF5FileLocation(path,dat,wvl)

Holds information about where data is within an HDF5 file

#Fields
- `path`: File path for the HDF5 file
- `dat`: Internal path to the relevant data
- `wvl`: Internal path to wavelength attribute
"""
struct HDF5FileLocation
    path::String
    dat::String
    wvl::String
end

"""
    safe_add_to_h5(h5file_obj,name,data)

Add file to hdf5 file, but it will replace the file if there is already a file that exists of the same name.
"""
function safe_add_to_h5(h5file_obj::HDF5.File,name::String,data) 

    try
        h5file_obj[name] = data
    catch
        println("Replacing $(name)...")
        delete_object(h5file_obj,name)
        h5file_obj[name] = data
    end
    return nothing
end

"""
    h52arr(h5fileloc::HDF5FileLocation)

Returns HDF5 data from h5fileloc in an array and the wavelength vector
"""
function h52arr(h5fileloc::HDF5FileLocation)
    arr,λ = h5open(h5fileloc.path) do f
        return read(f[h5fileloc.dat]),attrs(f)[h5fileloc.wvl]
    end
    return arr,λ
end

"""
    findλ(λ.targetλ)

Given a list of wavelengths, `λ`, find the index of a `targetλ` and the actual wavelength closest to your target.
"""
function findλ(λ::Vector{Float64},targetλ::Real)::Tuple{Int,Float64}
    idx = argmin(abs.(λ .- targetλ))
    return (idx,λ[idx])
end

"""
    img2h5(impath::String,h5loc::HDF5FileLocation)

Reads a .img or a .tif file at `impath` and writes it to the specified `h5loc`
"""
function img2h5(impath::String,h5loc::HDF5FileLocation)
    ds = AG.read(impath)
    arr = AG.read(ds)
    h5open(h5loc.path,"r+") do f
        safe_add_to_h5(f,h5loc.dat,arr)
    end
end