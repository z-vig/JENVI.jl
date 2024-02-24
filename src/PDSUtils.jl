using ENVI
import Base.size
using ProgressBars
using HDF5
using GLMakie

mutable struct LargeHDF5Array
    path::String
    h5obj::HDF5.File
    chunk::Array{Float64,3}
end

size(h5arr::LargeHDF5Array) = Base.size(h5arr.chunk)

function convert_envi(imgfile::String,hdrfile::String,h5file::String)
    envi_to_hdf5(imgfile,hdrfile,h5file)
    return h5file
end

function load_large_h5file(path)
    h5obj = h5open(path,"r+")
    arr::Array{Float32,3} = h5obj["raw/radiance"][:,:,1:100]
    return LargeHDF5Array(path,h5obj,arr)
end

function crop_fromlocfile(locdata::LargeHDF5Array,MIN_LAT::Float64,MAX_LAT::Float64,MIN_LONG::Float64,MAX_LONG::Float64)
    big_size = size(locdata.h5obj["raw/radiance"][1,1,:])
    start_index = 1
    all_good_indices::Vector{CartesianIndex{2}} = []
    for i ∈ tqdm(100:100:big_size[1])
        locdata.chunk = locdata.h5obj["raw/radiance"][:,:,start_index:i]
        #println(locdata.chunk[2,:,:])
        val = findall(locdata.chunk[1,:,:].>MIN_LAT .&& 
                      locdata.chunk[1,:,:].<MAX_LAT .&& 
                      locdata.chunk[2,:,:].>MIN_LONG .&& 
                      locdata.chunk[2,:,:].<MAX_LONG)

        if length(val)>0
            println("SAVING ROW: $i")
        end

        for i in eachindex(val)
            val[i] = val[i] + CartesianIndex(0,start_index-1)
        end

        start_index = 1+i
        append!(all_good_indices,val)
    end

    coord_matrix = [Tuple(i)[k] for i in all_good_indices,k in 1:2]
    println(size(coord_matrix))

    try
        locdata.h5obj["coords"] = coord_matrix
    catch e
        println(keys(locdata.h5obj))
        delete_object(locdata.h5obj,"coords")
        locdata.h5obj["coords"] = coord_matrix
    end
    return nothing
end

function crop_withcoords(coords::Array{Int},imobj::LargeHDF5Array;delete_badbands=false)
    arr = imobj.h5obj["raw/radiance"][:,minimum(coords[:,1]):maximum(coords[:,1]),minimum(coords[:,2]):maximum(coords[:,2])]
    arr = permutedims(arr,(2,3,1))

    if delete_badbands
        arr = arr[:,end:-1:1,9:end-1]
    else
        arr = arr[:,end:-1:1,:]
    end

    f = Figure()
    ax = Axis(f[1,1])

    image!(ax,arr[:,:,1],colorrange=(0,0.3))

    println(size(arr))
    
    display(GLMakie.Screen(),f)

    return arr
end

function setup_h5(dataset_savepath::String)
    h5open(dataset_savepath,"w") do h5file
        create_group(h5file,"VectorDatasets")
        create_group(h5file,"ScalarDatasets")
    end 
end

function initialize_hdf5(loc_envi_files::Tuple{String,String},
                         rfl_envi_files::Tuple{String,String},
                         obs_envi_files::Tuple{String,String},
                         crop_bounds::Vector{Float64},
                         dataset_savepath::String
)


    #Converting envi hdr and img files into hdf5 files and placing them in their current directory
    envi_files = [loc_envi_files,rfl_envi_files,obs_envi_files]
    readout = ["Converting LOC...","Converting RFL...","Converting OBS..."]
    h5paths = [] #loc,rfl,obs
    for i in 1:3
        nv = envi_files[i]
        h5savepath = "$(dirname(nv[1]))/$(basename(nv[1])[1:end-3])hdf5"
        push!(h5paths,h5savepath)
        if !isfile(h5savepath)
            println(readout[i])
            convert_envi(nv...,h5savepath)
        end
    end

    large_loc = load_large_h5file(h5paths[1])
    crop_fromlocfile(large_loc,crop_bounds...)
    setup_h5(dataset_savepath)

    save_paths = ["LocationBackplane","ObservationBackplane","VectorDatasets/RawSpectra"]

    h5open(dataset_savepath,"r+") do h5save
        h5save["LocationBackplane"] = crop_withcoords(large_loc.h5obj["coords"][:,:],large_loc)
        h5save["VectorDatasets/RawSpectra"] = crop_withcoords(large_loc.h5obj["coords"][:,:],load_large_h5file(h5paths[2]),delete_badbands=true)
        h5save["ObservationBackplane"] = crop_withcoords(large_loc.h5obj["coords"][:,:],load_large_h5file(h5paths[3]))
    end


end