using jenvi
using HDF5
using GLMakie
using Colors

arr, λ = h5open("D:/SelenoSpecData/MI_data/hdf5_files/rfl_data.hdf5") do ds
    return ds["Reflectance"][:, :, :], attrs(ds)["wavelength"]
end

em_config = Dict(
    "Fresh Mare" => ((815, 361), 1.0, :black),
    "Fresh Dome" => ((1336, 1478), 1.0, :blue),
    "Weathered Mare" => ((1112, 383), 1.0, :gray),
    "Olivine?" => ((1473, 1814), 1.3, :green),
    "Weathered Dome" => ((980, 1437), 1.0, :cyan),
    "Highlands" => ((196, 2204), 1.0, :pink)
)


endmembers = Vector{SAMEndmember}(undef, 0)
for (k, v) in em_config
    sme = SAMEndmember(arr[v[1]..., :], v[2], v[1], k, v[3])
    push!(endmembers, sme)
end

f = Figure()
ax = Axis(f[1,1], aspect = 5/4)
ax2 = Axis(f[1,3])

for em in endmembers
    lines!(ax, λ, em.data, label=em.name, color=em.color)
end
Legend(f[1, 2], ax, framevisible=false)

classified_map, class_key = SAM(arr, endmembers; classify=true)
clrs = [em.color for em in endmembers]
clrs = [:transparent, clrs...]
sl = IntervalSlider(
    f[2, 3], range=range(extrema(filter(isfinite, arr))..., 100), 
)
image!(ax2, arr[:, :, 2], colorrange=sl.interval)
ax2.aspect = DataAspect()
hidedecorations!(ax2)
image!(ax2, classified_map, colormap=clrs, interpolate=false, alpha=0.7)

olivine_pts = findall(x->x==class_key["Olivine?"], classified_map)
scatter!(
    getindex.(Tuple.(olivine_pts), 1),
    getindex.(Tuple.(olivine_pts), 2),
    color=:lime, strokecolor=:black, strokewidth=1
)
# Colorbar(f[1,4], limits=extrema(filter(isfinite,classified_map)), colormap=clrs)

rgb_arr = image_to_rgb_array(classified_map, clrs)

f2 = Figure(); ax3=Axis(f2[1,1])

show_img = map(CartesianIndices(axes(rgb_arr)[1:2])) do i
    x,y = Tuple(i)
    return RGBA(rgb_arr[x, y, :]...)
end

image!(ax3, show_img, interpolate=false)
println(class_key)
# println(name_list)

# h5open("D:/SelenoSpecData/MI_data/hdf5_files/rfl_data.hdf5", "r+") do ds
#     delete_object(ds, "SpectralAngleMap")
#     delete_object(ds, "SpectralAngleMap_RGB")
#     ds["SpectralAngleMap"] = float.(classified_map)
#     ds["SpectralAngleMap_RGB"] = rgb_arr
#     # attrs(ds)["SAM_colors"] = ["Red", "Green", "Blue"]
#     attrs(ds)["SAM_endmembers"] = name_list
# end

display(GLMakie.Screen(), f)
display(GLMakie.Screen(), f2)
