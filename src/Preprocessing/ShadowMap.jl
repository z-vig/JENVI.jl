using HDF5
using GLMakie
using Statistics

"""
    facet_shadowmap(dataset::HDF5.File)

TBW
"""
function facet_shadowmap(dataset::HDF5.File)
    obs = dataset["ObservationBackplane"]
    return (180/pi)*acos.(obs[:,:,10]) .> 80
    #dataset["FacetShadows"] = obs[]
end

"""
    lowsignal_shadowmap(dataset::HDF5.File)

TBW
"""
function lowsignal_shadowmap(dataset::HDF5.File)
    rawspec = dataset["VectorDatasets/RawSpectra"][:,:,:]
    return (mean(rawspec,dims=3) .< 0.06)[:,:,1]
end

# f = Figure()
# ax1 = Axis(f[1,1])
# ax2 = Axis(f[1,2])
# shad1 = facet_shadow_map(h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5"))
# shad2 = lowsignal_shadow_map(h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5"))
# image!(ax1,shad1)
# image!(ax2,shad2)

# display(GLMakie.Screen(),f)
