using HDF5
using Statistics

"""
    facet_shadowmap(dataset::HDF5.File)

TBW
"""
function facet_shadowmap(dataset::HDF5.File)
    obs = dataset["ObservationBackplane"]

    try
        delete_object(dataset,"ShadowMaps/facet_shadows")
    catch _
        println("Creating new facet shadow dataset...")
    end

    shmap = Int64.((180/pi)*acos.(obs[:,:,10]) .> 80)
    println(typeof(shmap))
    dataset["ShadowMaps/facet_shadows"] = shmap
    return nothing
end

"""
    lowsignal_shadowmap(dataset::HDF5.File)

TBW
"""
function lowsignal_shadowmap(dataset::HDF5.File)
    rawspec = dataset["VectorDatasets/RawSpectra"][:,:,:]

    try
        delete_object(dataset,"ShadowMaps/lowsignal_shadows")
    catch _
        println("Creating new low signal shadow dataset...")
    end

    shmap = Int64.(mean(rawspec,dims=3) .< 0.06)[:,:,1]
    dataset["ShadowMaps/lowsignal_shadows"] = shmap
    return nothing
end