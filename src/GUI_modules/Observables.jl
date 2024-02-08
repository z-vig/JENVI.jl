using GLMakie
using StatsBase
using PolygonOps
using ColorBrewer

function band_selector!(mod::GUIModule,location::Tuple{Int,Int})
    #Slider for adjusting the band that is being viewed on a multiple band image
    _ax = mod.figure[location...]
    _range = @lift(range(1,size($(mod.data).array,3)))
    _startvalue = @lift(size($(mod.data).array,3))

    band_slider = Slider(_ax,range=_range,startvalue=_startvalue,tellwidth=false)

    return band_slider.value
end

function histogram_selector!(mod::GUIModule,slider_loc::Tuple{Int,Int},histax::Axis;band_val::Union{Observable,Nothing} = nothing)
    #Slider for adjusting histogram of reflectance
    if !isnothing(band_val)
        histdata = @lift(vec($(mod.data).array[isfinite.($(mod.data).array)[:,:,1],$band_val]))
    else
        histdata = @lift(vec($(mod.data).array[isfinite.($(mod.data).array)]))
    end

    _fig = mod.figure[slider_loc...]
    _range = @lift(range(minimum($histdata),maximum($histdata),100))
    _startvals = @lift((percentile($histdata,1),percentile($histdata,99)))

    hist_slider = IntervalSlider(_fig,range=_range,startvalues=_startvals)

    on(_startvals) do x
        set_close_to!(hist_slider,x...)
        reset_limits!(histax)
    end

    bin_width = @lift(2*iqr($histdata)/(length($histdata))^(1/3))
    bin_edges = @lift(minimum($histdata):$bin_width:maximum($histdata))
    bin_avg = @lift([($bin_edges[i]+$bin_edges[i+1])/2 for i ∈ eachindex($bin_edges[1:end-1])])

    #Observables related to histogram slider
    imstretch = lift(hist_slider.interval) do inter
        inter
    end
    bin_colors = @lift(map($bin_avg) do val
                $(hist_slider.interval)[1] < val < $(hist_slider.interval)[2]
            end)

    hist!(histax,histdata,bins=bin_edges,color=bin_colors,colormap=[:transparent,:red],strokewidth=0.1)

    return imstretch
end

function menu_selector!(mod::GUIModule,location::Tuple{Int,Int},menuoptions::Dict{String,<:AbstractImageData};refaxis=nothing)
    _menu = Menu(mod.figure[location...],
                 options = zip(keys(menuoptions),values(menuoptions)),
                 default = collect(keys(menuoptions))[1],
                 tellheight = false,
                 tellwidth = false,
                 width = 150)

    on(_menu.selection) do sel
        mod.data[] = sel
        if !isnothing(refaxis)
            reset_limits!(refaxis)
        end
    end

    return _menu,_menu.selection
end

function clear_button!(plots_list::PlotsAccounting,figure::Figure)
    butt = Button(figure,label="Clear Plot",tellwidth=false,tellheight=false)

    function delete_clear!(plotsobj::PlotsAccounting,fieldname::Symbol)
        for i in getproperty(plotsobj,fieldname)
            delete!(i...)
        end
        setproperty!(plotsobj,fieldname,[])
    end
    
    on(butt.clicks) do x
        delete_clear!(plots_list,:pointspec_plots)
        delete_clear!(plots_list,:image_scatters)
        delete_clear!(plots_list,:image_polygons)
        delete_clear!(plots_list,:areaspec_plots)
        delete_clear!(plots_list,:areastd_plots)

        setproperty!(plots_list,:plot_number,1)
    end

    return butt
end

function plot_button!(plots_list::PlotsAccounting,figure::Figure,plotmod_list::Vector{GUIModule},specmod::GUIModule)
    butt = Button(figure,label="Plot Selection",tellwidth=false,tellheight=false)

    on(butt.clicks) do x

        for mod in plotmod_list
            rfl_map = poly!(mod.axis,plots_list.area_coordinates,strokewidth=1,color=plots_list.plot_number,colormap=:Set1_9,colorrange=(1,9),alpha=0.5)
            push!(plots_list.image_polygons,(mod.axis,rfl_map))
        end
        for s in plots_list.area_scatters
            s[2].color = :transparent
        end

        function run_inpolygon(pt::Vector{Int64})
            polyg = [[first(i),last(i)] for i in plots_list.area_coordinates]
            push!(polyg,polyg[1])
            return inpolygon(pt,polyg)
        end
        
        formatted_coords = hcat([first(i) for i in plots_list.area_coordinates],[last(i) for i in plots_list.area_coordinates])
        min_x = minimum(formatted_coords[:,1])
        max_x = maximum(formatted_coords[:,1])
        min_y = minimum(formatted_coords[:,2])
        max_y = maximum(formatted_coords[:,2])

        imcoords =  vec([[x,y] for x in 1:size(to_value(plotmod_list[1].data).array,1),y in 1:size(to_value(plotmod_list[1].data).array,2)])
        imcoords = hcat([i[1] for i in imcoords],[i[2] for i in imcoords])

        formatted_boxdata = []
        for (x,y) in zip(imcoords[:,1],imcoords[:,2])
            if x>min_x && x<max_x && y>min_y && y<max_y
                push!(formatted_boxdata,[x,y])
            end
        end

        inside_test = run_inpolygon.(formatted_boxdata)

        selection = [(i[1],i[2]) for i in formatted_boxdata[inside_test.==1]]

        formatted_boxdata = []

        selected_spectra = lift(specmod.data) do x
            zeros(length(selection),size(x.array,3))
        end

        @lift(for i in eachindex(selection)
                if count(isnan.($(specmod.data).array[selection[i]...,:])) == 0
                    $(selected_spectra)[i,:] = $(specmod.data).array[selection[i]...,:]
                end
            end)

        #Getting rid of zeros
        selected_spectra = @lift(view($selected_spectra,vec(mapslices(col->any(col .!= 0),$selected_spectra,dims=2)),:))

        μ = @lift(vec(mean($(selected_spectra),dims=1)))
        σ = @lift(vec(std($(selected_spectra),dims=1)))
        #println(to_value(selected_spectra))
        al = lines!(specmod.axis,@lift($(specmod.data).λ),μ,color=plots_list.plot_number,colormap=:Set1_9,colorrange=(1,9))

        al_std = band!(specmod.axis,@lift($(specmod.data).λ),@lift($μ.-$σ),@lift($μ.+$σ),color=palette("Set1",9)[plots_list.plot_number],alpha=0.3)
        
        push!(plots_list.areaspec_plots,(specmod.axis,al))
        push!(plots_list.areastd_plots,(specmod.axis,al_std))
        plots_list.area_coordinates = []
        plots_list.plot_number +=1
    end

    return butt

end

function init_obs(figdict::Dict{String,Figure},datadict::Dict{String,Array{Float64,3}},rawλ::Vector{Float64})
    f_rfl = figdict["Reflectance"]
    f_hist = figdict["Histogram"]
    f_spec = figdict["Spectra"]
    f_map = figdict["Map"]
    rflim = datadict["RawSpectra"]

    #Slider for adjusting the band that is being viewed on the reflectance image
    band_slider = Slider(f_rfl[2,1],range=range(1,size(rflim,3)),startvalue=size(rflim,3),tellwidth=false)
    
    #Observables related to band slider
    rfl_band = lift(band_slider.value) do val
        rflim[:,:,val]
    end
    band_string = lift(band_slider.value) do val
        "Showing $(rawλ[val]) nm band (#$(val))"
    end
    histdata = @lift(vec($rfl_band))


    #Slider for adjusting histogram of reflectance
    hist_slider = IntervalSlider(f_hist[2,1],range=@lift(range(minimum($histdata),maximum($histdata),100)),startvalues=@lift((percentile($histdata,1),percentile($histdata,99))))

    bin_width = @lift(2*iqr($histdata)/(length($histdata))^(1/3))
    bin_list = @lift(minimum($histdata):$bin_width:maximum($histdata))
    bin_avg = @lift([($bin_list[i]+$bin_list[i+1])/2 for i ∈ eachindex($bin_list[1:end-1])])
    #Observables related to histogram slider
    imstretch = lift(hist_slider.interval) do inter
        inter
    end
    clist = @lift(map($bin_avg) do val
                $(hist_slider.interval)[1] < val < $(hist_slider.interval)[2]
            end)

    #Menu for selecting spectra type
    specdict = Dict(i=>j for (i,j) in zip(keys(datadict),values(datadict)) if size(j,3)>1)

    spec_menu = Menu(f_spec[1,2],
        options=zip(keys(specdict),values(specdict)),default="RawSpectra",tellheight=false,width=200)
    
    spec_menu_options = lift(spec_menu.options) do x
        return x
    end
    spec_menu_selection = lift(spec_menu.selection) do x
        return x
    end

    #Menu for selecting data map
    mapdict = Dict(i=>j for (i,j) in zip(keys(datadict),values(datadict)) if size(j,3)==1)

    map_menu = Menu(f_map[1,2],options=zip(keys(mapdict),values(mapdict)),default="IBD1000",tellheight=false,width=150)

    map_menu_options = lift(map_menu.options) do x
        return x
    end
    map_menu_selection = lift(map_menu.selection) do x
        return x
    end

    #Slider for adjusting histogram of map
    histdata_map = @lift(vec($map_menu_selection))

    map_slider = IntervalSlider(f_hist[2,2],range=@lift(range(minimum($histdata_map),maximum($histdata_map),1000)),startvalues=@lift((percentile($histdata_map,1),percentile($histdata_map,99))))

    bin_width = @lift(2*iqr($histdata_map)/(length($histdata_map))^(1/3))
    bin_list = @lift(minimum($histdata_map):$bin_width:maximum($histdata_map))
    bin_avg = @lift([($bin_list[i]+$bin_list[i+1])/2 for i ∈ eachindex($bin_list[1:end-1])])
    #Observables related to histogram slider
    imstretch_map = lift(map_slider.interval) do inter
        inter
    end
    clist_map = @lift(map($bin_avg) do val
                $(map_slider.interval)[1] < val < $(map_slider.interval)[2]
            end)

    
    obs_dict::Dict{String,Observable} = Dict(
        "rfl_band" => rfl_band,
        "band_string" => band_string,
        "histdata" => histdata,
        "imstretch" => imstretch,
        "clist" => clist,
        "histdata_map" => histdata_map,
        "imstretch_map" => imstretch_map,
        "clist_map" => clist_map,
        "spec_menu_options" => spec_menu_options,
        "spec_menu_selection" => spec_menu_selection,
        "map_menu_options" => map_menu_options,
        "map_menu_selection" => map_menu_selection
        )

    return obs_dict

end