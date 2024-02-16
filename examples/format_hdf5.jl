using Statistics
using GLMakie
using HDF5
SHOW_TREE_ICONS = true

function sort_h5(h5path)
    h5file = h5open(h5path,"r+")
    for key in keys(h5file)
        if typeof(h5file[key])==HDF5.Dataset
            num_dims=ndims(read_dataset(h5file,key))
            if num_dims == 3
                copy_object(h5file[key],h5file,"VectorDatasets/$(key)")
                delete_object(h5file,key)
            elseif num_dims == 2
                copy_object(h5file[key],h5file,"ScalarDatasets/$(key)")
                delete_object(h5file,key)
            end
        end
    end
end

function add_dataset(h5src,h5dst)
    src = h5open(h5src,"r")
    dst = h5open(h5dst,"r+")

    coord_h5 = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global_crop_coordinates2.hdf5")

    coords = coord_h5["coords"][:,:]

    obs_arr = src["raw/radiance"][:,minimum(coords[:,1]):maximum(coords[:,1]),minimum(coords[:,2]):maximum(coords[:,2])]
    obs_arr = permutedims(obs_arr,(2,3,1))
    obs_arr = obs_arr[:,end:-1:1,:]
    f = Figure()
    ax = Axis(f[1,1])
    image!(ax,obs_arr[:,:,10])
    display(GLMakie.Screen(),f)
    create_group(dst,"Backplanes")
    #delete_object(dst["Backplanes/obs"])
    dst["Backplanes/obs"] = obs_arr

    close(src)
    close(dst)
    close(coord_h5)

end

function display_h5file(h5path)
    h5file = h5open(h5path)
    println("\n---$(basename(h5path))---")
    for i in keys(h5file)
        println(i)
        for j in keys(h5file[i])
            println("  --> $j, $(size(read(h5file["$i/$j"])))")
        end
    end
    close(h5file)
end

#sort_h5("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2.hdf5")
add_dataset("C:/Lunar_Imagery_Data/gruithuisen_m3global_L1B/obs_194335.hdf5","C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2.hdf5")
display_h5file("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_target.hdf5")
display_h5file("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global1.hdf5")
display_h5file("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2.hdf5")

GC.gc()