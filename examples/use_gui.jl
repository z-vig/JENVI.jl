using JENVI
using GLMakie
using HDF5

function load_data(dataset::HDF5.File;global_data=true,shadow_type="lowmean")
    if global_data==true
        λ = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global_wvl/smoooth_wvl.txt"))]

        h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_global1.hdf5")
    else
        λ = [parse(Float64,i) for i in readlines(open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/wvl/smoothed_wvl_data.txt"))]

        h5file = h5open("C:/Users/zvig/.julia/dev/JENVI.jl/Data/gamma_maps_target.hdf5")
    end

    shadowmap = read(h5file["ShadowMaps/$shadow_type"])

    all_data = Dict{String,AbstractImageData}()
    for key ∈ keys(h5file)
        for dataset ∈ keys(h5file[key])
            if key == "ScalarDatasets"
                all_data[dataset] = MapData(dataset,read(h5file["$key/$dataset"]),shadowmap,λ)
            elseif key == "VectorDatasets"
                all_data[dataset] = SpecData(dataset,read(h5file["$key/$dataset"]),shadowmap,λ)
            end
        end
    end

    all_data["FacetAngle"] = MapData("FacetAngle",h5file["Backplanes/obs"][:,:,10],shadowmap,λ)

    all_data["PhaseAngle"] = MapData("PhaseAngle",h5file["Backplanes/obs"][:,:,5],shadowmap,λ)
    close(h5file)

    return all_data
end

function run_gui(;global_data=true)
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

#@time run_gui(global_data=true)
@time run_gui(global_data=false)
GC.gc()
