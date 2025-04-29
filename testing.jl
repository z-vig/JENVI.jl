using jenvi
using HDF5
using GLMakie

arr, λ = h5open("D:/SelenoSpecData/MI_data/hdf5_files/rfl_data.hdf5") do ds
    return ds["Reflectance"][:, :, :], attrs(ds)["wavelength"]
end

em_config = Dict(
    "Fresh Mare" => ((815, 361), 5),
    "Fresh Dome" => ((1336, 1478), 5),
    "Weathered Mare" => ((1112, 383), 5),
    "Olivine?" => ((1473, 1814), 5)
)

data = Array{Float64}(undef, length(em_config), size(arr, 3))
thresh = Vector{Float64}(undef, length(em_config))
names = Vector{String}(undef, length(em_config))
for (n, (k, v)) in enumerate(em_config)
    data[n, :] = arr[v[1]..., :]
    thresh[n] = v[2]
    names[n] = k
end
se = SAMEndmembers(data, thresh, names)

f = Figure()
ax = Axis(f[1,1])
ax2 = Axis(f[1,3])
for (n, i) in enumerate(eachrow(se.data))
    lines!(ax, λ, i, label=se.names[n])
end
Legend(f[1, 2], ax, framevisible=false)

classified_map = SAM(arr, se; classify=true)
image!(ax2, classified_map)

display(GLMakie.Screen(), f)
