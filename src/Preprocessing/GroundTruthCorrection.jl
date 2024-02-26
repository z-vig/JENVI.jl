using HDF5

"""
    apply_gnd_tru(rfl_arr::Array{Float32},gnd_tru_λ::Vector{Float64})

    Function for applying the ground truth correction to M3 Data
"""

function apply_gnd_tru(gndtru_path::String,dataset::HDF5.File,dataset_type::String)
    rfl_arr = dataset["VectorDatasets/RawSpectra"][:,:,:]
    gndtru_vals = open(gndtru_path) do f
        s = readlines(f)
        s = s .|> x->split(x,"  ") |> x->deleteat!(x,x.=="") |> x->parse.(Float64,x)
        s = transpose(stack(s))
        if dataset_type == "targeted"
            return s[9:end-1,3]
        elseif dataset_type == "global"
            return s[3:end,3]
        else
            println("Invalid Dataset Type")
        end
    end

    rfl_arr_gndtru = mapslices(x -> x.*gndtru_vals, rfl_arr, dims=3)

    try
        delete_object(dataset,"VectorDatasets/RawSpectra_GNDTRU")
    catch _
        println("Creating new ground truth corrected dataset...")
    end

    dataset["VectorDatasets/RawSpectra_GNDTRU"] = rfl_arr_gndtru

    return rfl_arr_gndtru
end

#apply_gnd_tru("C:/Lunar_Imagery_Data/gruithuisen_m3target_L1B/grnd_tru1.tab",h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5"),"targeted")