using JENVI
using GLMakie
using HDF5

function load_data(;global_data=true)
    if global_data==true
        λ = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global_wvl/smoooth_wvl.txt"))]

        h5file1 = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/shadow_bits_global2.hdf5")
        shadow_mask = Bool.(read(h5file1["gamma"]))
        close(h5file1)

        h5file2 = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global2.hdf5")
    else
        λ = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/wvl/smoothed_wvl_data.txt"))]

        h5file1 = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/shadow_bits.hdf5")
        shadow_mask = Bool.(read(h5file1["gamma"]))
        close(h5file1)

        h5file2 = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps.hdf5")
    end

    all_data = Dict{String,AbstractImageData}()
    for i ∈ eachindex(keys(h5file2))
        key = keys(h5file2)[i]
        arr = read(h5file2[key])

        if ndims(arr) < 3
            all_data[key] = MapData(key,arr,shadow_mask,λ)
        else
            all_data[key] = SpecData(key,arr,shadow_mask,λ)
        end
    end
    close(h5file2)

    return all_data
end

function run_gui_new(;global_data=true)
    @time datadict = load_data(global_data=global_data)
    specdict = Dict(i[1]=>i[2] for i in datadict if ndims(i[2].array)==3)
    mapdict::Dict{String,<:AbstractImageData} = Dict(i[1]=>i[2] for i in datadict if ndims(i[2].array)<3)
    for i in mapdict
        println(typeof(i[2]))
    end

    println("Currently Loaded Datasets:")
    for key in collect(keys(datadict))
        println("---$key---")
    end

    fig1 = Figure()
    fig2 = Figure()
    rfl_module = GUIModule(fig1,Axis(fig1[1,1]),Observable(datadict["SmoothSpectra"]))
    map_module = GUIModule(fig1,Axis(fig1[1,2]),Observable(mapdict[collect(keys(mapdict))[1]]))
    spectral_module = GUIModule(fig2,Axis(fig2[1,1],height=350,width=500),Observable(specdict[collect(keys(specdict))[1]]))
    
    band_val = band_selector!(rfl_module,(2,1))
    rfl_imstretch = histogram_selector!(rfl_module,(4,1),Axis(fig1[3,1],height=70),band_val=band_val)
    map_imstretch = histogram_selector!(map_module,(4,2),Axis(fig1[3,2],height=70))
    menu_obj,menu_selection = menu_selector!(map_module,(2,2),mapdict,refaxis=map_module.axis)
    spec_menu_obj,spec_menu_selection = menu_selector!(spectral_module,(1,2),specdict,refaxis=spectral_module.axis)

    plots_list = PlotsAccounting(1,[],[],[],[],[],[],[])

    clearbutton_obj = clear_button!(plots_list,fig2)
    plotbutton_obj = plot_button!(plots_list,fig2,[rfl_module,map_module],spectral_module)

    fig2[2,1] = buttongrid = GridLayout(tellwidth=false,height=50)
    buttongrid[1,1:2] = [clearbutton_obj,plotbutton_obj]

    activate_pointgrab!(plots_list,rfl_module,spectral_module,:spectral_grab1,[map_module.axis])
    activate_pointgrab!(plots_list,map_module,spectral_module,:spectral_grab2,[rfl_module.axis])
    activate_areagrab!(plots_list,rfl_module,:area_grab1,[map_module.axis])
    activate_areagrab!(plots_list,map_module,:area_grab2,[rfl_module.axis])

    image!(rfl_module.axis,@lift($(rfl_module.data).array[:,:,$band_val]),colorrange=rfl_imstretch,nan_color=:purple)
    image!(map_module.axis,@lift($(map_module.data).array),colorrange=map_imstretch,nan_color=:purple)

    for fig in [fig1,fig2]
        display(GLMakie.Screen(),fig)
    end

    return nothing
end

function run_gui()
    specdata = Dict(i=>j for (i,j) in zip(keys(all_data),values(all_data)) if size(j,3)>1)

    mapdata = Dict(i=>j[:,:,1] for (i,j) in zip(keys(all_data),values(all_data)) if size(j,3)==1)

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

#@time run_gui_new(global_data=true)
@time run_gui_new(global_data=false)
# @time run_gui()
GC.gc()
