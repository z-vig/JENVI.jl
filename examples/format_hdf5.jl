using Statistics
using GLMakie
using HDF5

function do_thing()
    h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2.hdf5")
    arr = read(h5file["SmoothSpectra"])
    # arr_vec = Vector{Union{Array{<:AbstractFloat,3},Array{<:AbstractFloat,2}}}(undef,11)
    # key_list = keys(h5file)
    # for i in eachindex(keys(h5file))
    #     key = keys(h5file)[i]
    #     println(key)
    #     arr_vec[i] = read(h5file[key])
    #     println(size(arr_vec[i]))
    # end

    # close(h5file)

    # arr_vec[end-3] = arr_vec[end-3][:,:,3:end-2]
    # # arr_vec[end] = arr_vec[end][:,:,1]
    # # arr_vec[end-1] = arr_vec[end-1][:,:,1]

    # println(size(arr_vec[end-3]))

    # h5save = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2_NEW.hdf5","w")
    # for i in eachindex(key_list)
    #     println(size(arr_vec[i]))
    #     h5save[key_list[i]] = arr_vec[i]
    # end
    # close(h5save)

    shadow_pix = mean(arr,dims=3)
    # h5save = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/shadow_bits_global2.hdf5","w")
    # h5save["gamma"] = Int.(shadow_pix[:,:,1].<0.05)
    # close(h5save)

    f=Figure()
    ax=Axis(f[1,1])
    image!(ax,shadow_pix[:,:,1].<0.05)
    display(GLMakie.Screen(),f)
    return nothing
end

function do_other_thing()
    h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2.hdf5")
    arr = read(h5file["RawSpectra"])
    
    close(h5file)
end

#do_other_thing()
do_thing()
GC.gc()