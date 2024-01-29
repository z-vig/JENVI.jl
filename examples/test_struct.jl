using JENVI
using GLMakie
using HDF5

function run_gui()
    h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps.hdf5")
    all_data = Dict{String,Array{Float64,3}}()
    for i ∈ eachindex(keys(h5file))
        key = keys(h5file)[i]
        arr = read(h5file[key])
        if ndims(arr) < 3
            arr = reshape(arr,(size(arr)...,1))
        end
        all_data[key] = arr
    end
    close(h5file)

    specdata = Dict(i=>j for (i,j) in zip(keys(all_data),values(all_data)) if size(j,3)>1)

    mapdata = Dict(i=>j[:,:,1] for (i,j) in zip(keys(all_data),values(all_data)) if size(j,3)==1)

    h5file2 = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/shadow_bits.hdf5")
    shadow_bits = Bool.(read(h5file2["gamma"]))
    close(h5file2)

    mod1 = GUIModule{Array{Float64,3}}(Figure(),Observable{Array{Float64,3}}(all_data["SmoothSpectra"]),shadow_bits)
    shadow_removal!(mod1)
    axrfl = Axis(mod1.figure[1,1])

    band_value = band_selector!(mod1,(2,1))
    band_image::Observable{Matrix{Float64}} = @lift($(mod1.data)[:,:,$band_value])

    mod2 = GUIModule{Matrix{Float64}}(Figure(),band_image,shadow_bits)
    shadow_removal!(mod2)
    axhist_rfl = Axis(mod2.figure[1,1])

    imstretch_rfl,bin_edges_rfl,bin_colors_rfl = histogram_selector!(mod2,(2,1),axhist_rfl)

    mod3 = GUIModule{Matrix{Float64}}(Figure(),Observable(collect(values(mapdata))[1]),shadow_bits)
    shadow_removal!(mod3)
    axmap = Axis(mod3.figure[1,1])

    mod4 = GUIModule{Matrix{Float64}}(mod2.figure,mod3.data,shadow_bits)
    shadow_removal!(mod4)
    axhist_map = Axis(mod4.figure[1,2])

    map_options,map_selection = menu_selector!(mod3,(1,2),mapdata,axhist_map)

    imstretch_map,bin_edges_map,bin_colors_map = histogram_selector!(mod4,(2,2),axhist_map)

    mod5 = GUIModule{Array{Float64,3}}(Figure(),Observable(collect(values(specdata))[1]),shadow_bits)

    activate_spectral_grab()

    image!(axrfl,band_image,colorrange=imstretch_rfl,nan_color=:purple)
    hist!(axhist_rfl,@lift(vec($(mod2.data)[isfinite.($(mod2.data))])),
          bins = bin_edges_rfl,
          color = bin_colors_rfl,
          colormap=[:transparent,:red],
          strokewidth=0.1)
    
    image!(axmap,mod3.data,colorrange=imstretch_map,nan_color=:purple)
    hist!(axhist_map,@lift(vec($(mod3.data)[isfinite.($(mod3.data))])),
          bins = bin_edges_map,
          color = bin_colors_map,
          colormap = [:transparent,:red],
          strokewidth = 0.1)

    display(GLMakie.Screen(),mod1.figure)
    display(GLMakie.Screen(),mod2.figure)
    display(GLMakie.Screen(),mod3.figure)

    return nothing
end

@time run_gui()
GC.gc()
