function norm_im(arr::Matrix{<:AbstractFloat})
    real_arr = arr[isfinite.(arr)]
    return (arr .- minimum(real_arr)) ./ (maximum(real_arr) - minimum(real_arr))
end

function norm_im_controlled(arr::Matrix{<:AbstractFloat},lo::T,hi::T) where {T<:AbstractFloat}
    arr[arr.>hi] .= hi
    arr[arr.<lo] .= lo
    return (arr .- lo) ./ (hi - lo)
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
    findλ(λ.targetλ)

Given a list of wavelengths, `λ`, find the index of a `targetλ` and the actual wavelength closest to your target.
"""
function findλ(λ::Vector{Float64},targetλ::Real)::Tuple{Int,Float64}
    idx = argmin(abs.(λ .- targetλ))
    return (idx,λ[idx])
end

# """
#     img2h5(impath::String,h5loc::HDF5FileLocation)

# Reads a .img or a .tif file at `impath` and writes it to the specified `h5loc`
# """
# function img2h5(impath::String,h5loc::)
#     ds = AG.read(impath)
#     arr = AG.read(ds)
#     h5open(h5loc.path,"r+") do f
#         safe_add_to_h5(f,h5loc.dat,arr)
#     end
# end