using JENVI
using GLMakie
using HDF5

function load_data(h5file::HDF5.File)

    rawλ = read_attribute(h5file,"raw_wavelengths")
    smoothλ = read_attribute(h5file,"smooth_wavelengths")

    shadowmap = h5file["ShadowMaps/lowsignal_shadows"][:,:]

    all_data = Dict{String,AbstractImageData}()
    for key ∈ keys(h5file)
        if typeof(h5file[key]) == HDF5.Group
            for dataset ∈ keys(h5file[key])
                if key == "ScalarDatasets"
                    println(size(h5file["$key/$dataset"]),dataset)
                    all_data[dataset] = MapData(dataset,read(h5file["$key/$dataset"]),shadowmap,smoothλ)
                elseif key == "VectorDatasets"
                    if dataset == "RawSpectra" || dataset == "RawSpectra_GNDTRU"
                        all_data[dataset] = SpecData(dataset,read(h5file["$key/$dataset"]),shadowmap,rawλ)
                    else
                        all_data[dataset] = SpecData(dataset,read(h5file["$key/$dataset"]),shadowmap,smoothλ)
                    end
                end
            end
        end
    end

    #([size(h5file["ObservationBackplane"][:,:,i]) for i in 1:size(h5file["ObservationBackplane"],3)])
    all_data["Observation"] = ObservationData([h5file["Backplanes/ObsGeometry"][:,:,i] for i in 1:size(h5file["Backplanes/ObsGeometry"],3)]...,shadowmap)
    all_data["Location"] = LocationData([h5file["Backplanes/LatLongElev"][:,:,i] for i in 1:size(h5file["Backplanes/LatLongElev"],3)]...,shadowmap)
    close(h5file)

    return all_data
end

function run_gui(h5filepath)
    @time datadict = load_data(h5open(h5filepath))
    specdict::Dict{String,<:AbstractImageData} = Dict(i[1]=>i[2] for i in datadict if typeof(i[2])==SpecData)
    mapdict::Dict{String,<:AbstractImageData} = Dict(i[1]=>i[2] for i in datadict if typeof(i[2])==MapData)
    obsobj = datadict["Observation"]
    locobj = datadict["Location"]

    println("Currently Loaded Datasets:")
    for key in collect(keys(datadict))
        println("---$key---")
    end

    fig1 = Figure()
    fig2 = Figure()
    fig3 = Figure()
    rfl_module = GUIModule(fig1,Axis(fig1[1,1]),Observable(datadict["SmoothSpectra_GNDTRU"]))
    map_module = GUIModule(fig1,Axis(fig1[1,2]),Observable(mapdict[collect(keys(mapdict))[2]]))
    location_module = GUIModule(fig3,Axis(fig3[1,1]),Observable(obsobj))
    specax = Axis(
        fig2[1,1], height=350,width=500,
        xminorticksvisible = true,
        xticks = 1000:500:3000,
        xminorticks = IntervalsBetween(5)
    )

    println(typeof(rfl_module))

    spectral_module = GUIModule(fig2,specax,Observable(specdict[collect(keys(specdict))[1]]))
    
    band_val = band_selector!(rfl_module,(2,1))
    rfl_imstretch = histogram_selector!(rfl_module,(4,1),Axis(fig1[3,1],height=70),band_val=band_val)

    map_imstretch = histogram_selector!(map_module,(4,2),Axis(fig1[3,2],height=70))
    menu_obj,menu_selection = menu_selector!(map_module,(2,2),mapdict,refaxis=map_module.axis)
    spec_menu_obj,spec_menu_selection = menu_selector!(spectral_module,(1,2),specdict,refaxis=spectral_module.axis)

    plots_list = PlotsAccounting()

    clearbutton_obj = clear_button!(plots_list,fig2)
    plotbutton_obj = plot_button!(plots_list,fig2,[rfl_module,map_module],spectral_module)
    savebutton_obj = save_button!(plots_list,fig2,"C:/Users/zvig/.julia/dev/JENVI.jl/Data/SavedGUIData")
    printbutton_obj = print_button!(plots_list,fig3,[location_module],spectral_module)

    fig2[2,1] = buttongrid = GridLayout(tellwidth=false,height=50)
    buttongrid[1,1:3] = [clearbutton_obj,plotbutton_obj,savebutton_obj]

    println(typeof(printbutton_obj))
    fig3[1,2] = printbutton_obj

    activate_pointgrab!(plots_list,rfl_module,spectral_module,:spectral_grab1,[map_module.axis],locobj,obsobj)
    activate_pointgrab!(plots_list,map_module,spectral_module,:spectral_grab2,[rfl_module.axis],locobj,obsobj)
    activate_areagrab!(plots_list,rfl_module,:area_grab1,[map_module.axis])
    activate_areagrab!(plots_list,map_module,:area_grab2,[rfl_module.axis])
    activate_areaprint!(plots_list,location_module,:print_grab)


    image!(rfl_module.axis,@lift($(rfl_module.data).array[:,:,$band_val]),colorrange=rfl_imstretch,nan_color=:purple)
    image!(map_module.axis,@lift($(map_module.data).array),colorrange=map_imstretch,nan_color=:purple)
    image!(location_module.axis,@lift($(location_module.data).m3_azi))

    for fig in [fig1,fig2,fig3]
        display(GLMakie.Screen(),fig)
    end

    return fig2
end

#@time run_gui(global_data=true)
@time f = run_gui("C:/Users/zvig/.julia/dev/JENVI.jl/Data/targeted.hdf5")
# @time run_gui("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global1.hdf5")
# @time run_gui("C:/Users/zvig/.julia/dev/JENVI.jl/Data/global2.hdf5")
GC.gc()