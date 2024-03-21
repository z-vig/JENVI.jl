using GLMakie
using StatsBase
using PolygonOps
using ColorBrewer
using Dates
using JENVI

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
    println(nquantile(to_value(histdata),4)," ",length(to_value(histdata)))
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
                 width = 260)

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
        delete_clear!(plots_list,:plotted_data)

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
        
        push!(plots_list.plotted_data,to_value(μ))
        push!(plots_list.areaspec_plots,(specmod.axis,al))
        push!(plots_list.areastd_plots,(specmod.axis,al_std))
        plots_list.area_coordinates = []
        plots_list.plot_number +=1
    end

    return butt

end

function save_button!(plots_list::PlotsAccounting,figure::Figure,savefolder::String)
    butt = Button(figure,label="Save Spectra",tellwidth=false,tellheight=false)

    on(butt.clicks) do x
        nowstr = string(now())
        nowstr = nowstr[1:end-4]|>x->replace(x,"-"=>"")|>x->replace(x,":"=>"")
        open("$savefolder/save_$(nowstr).txt","w") do f
            for i in plots_list.plotted_data
                strlist = ["$i," for i in string.(i)]
                strlist[end] = replace(strlist[end],","=>"\n")
                write(f,strlist...)
            end
        end
        
        #save_myfig(figure,"G:/Shared drives/Zach Lunar-VISE/Research Presentations/LPSC24/current_gui.svg")

    end

    return butt

end

function print_button!(plots_list::PlotsAccounting,figure::Figure,plotmod_list::Vector{GUIModule{ObservationData}},specmod::GUIModule)
    butt = Button(figure,label="Print Selection",tellwidth=false,tellheight=false)

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

        imcoords = vec([[x,y] for x in 1:size(to_value(plotmod_list[1].data).facet_angle,1),y in 1:size(to_value(plotmod_list[1].data).facet_angle,2)])
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

        println(typeof(plotmod_list[1]))
        fct_ang = []
        phs_ang = []
        incid = []
        emiss = []
        m3_az = []
        sun_azi = []

        @lift(for i in eachindex(selection)
            push!(fct_ang,$(plotmod_list[1].data).facet_angle[selection[i]...])
            push!(phs_ang,$(plotmod_list[1].data).phase[selection[i]...])
            push!(incid,$(plotmod_list[1].data).sun_zen[selection[i]...])
            push!(emiss,$(plotmod_list[1].data).m3_zen[selection[i]...])
            push!(m3_az,$(plotmod_list[1].data).m3_azi[selection[i]...])
            push!(sun_azi,$(plotmod_list[1].data).sun_azi[selection[i]...])
        end)
        
        μ_fct = mean(fct_ang)
        σ_fct = std(fct_ang)

        μ_phs = mean(phs_ang)
        σ_phs = std(phs_ang)

        μ_incid = mean(incid)
        σ_incid = std(incid)

        μ_emiss = mean(emiss)
        σ_emiss = std(emiss)

        μ_m3az = mean(m3_az)
        σ_m3az = std(m3_az)

        μ_sunazi = mean(sun_azi)
        σ_sunazi = std(sun_azi)

        println("Facet Angle: $(μ_fct) ± $(σ_fct)")
        println("Phase Angle: $(μ_phs) ± $(σ_phs)")
        println("Incidence Angle: $(μ_incid) ± $(σ_incid)")
        println("Emmision Angle: $(μ_emiss) ± $(σ_emiss)")
        println("M3 Azimuth: $(μ_m3az) ± $(σ_m3az)")
        println("Sun Azimuth: $(μ_sunazi) ± $(σ_sunazi)")

    end

    return butt
        
end