#JenviGUI.jl
module JenviGUI
export ask_file,build_gui,init_fig,init_obs,reflectanceviewer,mapviewer,histogramviewer,spectralviewer

using GLMakie
using StatsBase
using PolygonOps
using Gtk4
using ColorBrewer

function ask_file(start_folder::String)
    path = open_dialog("Select Image to Visualize",parent(GtkWindow()),start_folder=start_folder)
    if isfile(path)
        return path
    else
        println("Please Select a file")
    end
end

function init_fig()
    figdict = Dict{String,Figure}()
    dictkeys = ["Reflectance","Map","Histogram","Spectra"]
    for key ∈ dictkeys
        figdict[key] = Figure()
    end
    return figdict
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

function reflectanceviewer(figdict::Dict{String,Figure},obsdict::Dict{String,Observable})
    f_rfl = figdict["Reflectance"]
    ax_rfl = GLMakie.Axis(f_rfl[1,1],width=900,height=900)
    ax_rfl.title = "Reflectance Image"
    resize_to_layout!(f_rfl)

    rfl_band = obsdict["rfl_band"]

    image!(ax_rfl,rfl_band,colorrange=obsdict["imstretch"],interpolate=false,nan_color=:purple)

    Label(f_rfl[3,1],obsdict["band_string"],tellwidth=false)

    display(GLMakie.Screen(),f_rfl)
end

function mapviewer(figdict::Dict{String,Figure},obsdict::Dict{String,Observable},datadict::Dict{String,Array{Float64,3}})
    f_map = figdict["Map"]
    ax_map = GLMakie.Axis(f_map[1,1])

    map_select = Observable{Array{Float64,2}}(datadict["IBD1000"][:,:,1])
    on(obsdict["map_menu_selection"]) do sel
        map_select[] = sel[:,:,1]
    end
    
    image!(ax_map,map_select,colorrange=obsdict["imstretch_map"],interpolate=false,nan_color=:purple)
    
    display(GLMakie.Screen(),f_map)
end

function histogramviewer(figdict::Dict{String,Figure},obsdict::Dict{String,Observable})

    f_hist = figdict["Histogram"]
    ax_hist = GLMakie.Axis(f_hist[1,1])
    ax_hist_map = GLMakie.Axis(f_hist[1,2])

    histdata = obsdict["histdata"]
    clist = obsdict["clist"]
    bin_width = @lift(2*iqr($histdata)/(length($histdata))^(1/3))
    bin_list = @lift(minimum($histdata):$bin_width:maximum($histdata))

    histdata_map = obsdict["histdata_map"]
    clist_map = obsdict["clist_map"]
    bin_width_map = @lift(2*iqr($histdata_map)/(length($histdata_map))^(1/3))
    bin_list_map = @lift(minimum($histdata_map):$bin_width_map:maximum($histdata_map))

    hist!(ax_hist,histdata,bins=bin_list,color=clist,colormap=[:transparent,:red],strokewidth=0.1)

    hist!(ax_hist_map,histdata_map,bins=bin_list_map,color=clist_map,colormap=[:transparent,:Red],strokewidth=0.1)

    display(GLMakie.Screen(),f_hist)
end

function spectralviewer(figdict::Dict{String,Figure},obsdict::Dict{String,Observable},datadict::Dict{String,Array{Float64,3}},rawλ::Vector{Float64},smoothλ::Vector{Float64})
    f_spec = figdict["Spectra"]
    f_rfl = figdict["Reflectance"]
    f_map = figdict["Map"]
    colsize!(f_spec.layout,1,Fixed(600))
    resize_to_layout!(f_spec)

    ax_spec = GLMakie.Axis(f_spec[1,1])
    xlims!(ax_spec,(minimum(rawλ),maximum(rawλ)))
    ax_spec.xlabel = "Wavelength (nm)"
    ax_spec.ylabel = "Reflectance"

    spectra_select = Observable{Array{Float64,3}}(datadict["RawSpectra"])
    λ_select = Observable{Vector{Float64}}(smoothλ)

    on(obsdict["spec_menu_selection"]) do sel
        spectra_select[] = sel
        if size(sel,3) == length(rawλ)
            λ_select[] = rawλ
        elseif size(sel,3) == length(smoothλ)
            λ_select[] = smoothλ
        end
        reset_limits!(ax_spec)
        println(@lift(size($spectra_select)))
        println(@lift(size($λ_select)))
    end

    imcoords =  vec([[x,y] for x in 1:size(to_value(spectra_select),1),y in 1:size(to_value(spectra_select),2)])
    imcoords = hcat([i[1] for i in imcoords],[i[2] for i in imcoords])

    pllist = []
    pslist = []
    num_spectra = 0
    register_interaction!(f_rfl.content[2],:get_spectra) do event::MouseEvent,axis
        if event.type==MouseEventTypes.leftclick
            if num_spectra<9
                num_spectra += 1
            else
                num_spectra = 1
            end
            xpos = Int(round(event.data[1]))
            ypos = Int(round(event.data[2]))

            pl = lines!(ax_spec,λ_select,@lift($(spectra_select)[xpos,ypos,:]),color=num_spectra,colormap=:Set1_9,colorrange=(1,9),linestyle=:dash)

            ps = scatter!(f_rfl.content[2],xpos,ypos,color=num_spectra,colormap=:Set1_9,colorrange=(1,9),markersize=5)
            push!(pllist,pl)
            push!(pslist,ps)
            println("X:$xpos, Y:$ypos")
        end
    end

    slist_rfl = []
    slist_map = []
    coordlist::Vector{Tuple{Float64,Float64}} = []
    register_interaction!(f_rfl.content[2],:area_spectra_rfl) do event::KeysEvent, axis
        if all([i in event.keys for i in [Keyboard.q,Keyboard.left_shift]])
            mp = mouseposition(f_rfl.content[2])
            xpos = mp[1]
            ypos = mp[2]
            srfl = scatter!(f_rfl.content[2],xpos,ypos,color=:Red)
            smap = scatter!(f_map.content[2],xpos,ypos,color=:Red)
            push!(slist_rfl,srfl)
            push!(slist_map,smap)
            push!(coordlist,(xpos,ypos))
        end
    end

    register_interaction!(f_map.content[2],:area_spectra_map) do event::KeysEvent, axis
        if all([i in event.keys for i in [Keyboard.q,Keyboard.left_shift]])
            mp = mouseposition(f_map.content[2])
            xpos = mp[1]
            ypos = mp[2]
            srfl = scatter!(f_rfl.content[2],xpos,ypos,color=:Red)
            smap = scatter!(f_map.content[2],xpos,ypos,color=:Red)
            push!(slist_rfl,srfl)
            push!(slist_map,smap)
            push!(coordlist,(xpos,ypos))
        end
    end

    b_select = Button(f_rfl,label="Plot Selection")
    b_clear = Button(f_rfl,label="Clear Selection")
    f_rfl[1, 2] = buttongrid = GridLayout(tellheight = false)
    buttongrid[1:2,1] = [b_select,b_clear]

    area_spectra_num = 0
    allist = []
    allist_std = []
    poly_list = []
    poly_list_map = []
    on(b_select.clicks) do x
        if area_spectra_num<9
            area_spectra_num += 1
        else
            area_spectra_num = 1
        end

        for s in slist_rfl
            s.color = :transparent
        end
        for s in slist_map
            s.color = :transparent
        end

        # println(length(coordlist))
        p = poly!(f_rfl.content[2],coordlist,strokewidth=1,color=area_spectra_num,colormap=:Set1_9,colorrange=(1,9),alpha=0.5)
        pmap = poly!(f_map.content[2],coordlist,strokewidth=1,color=area_spectra_num,colormap=:Set1_9,colorrange=(1,9),alpha=0.5)
        push!(poly_list,p)
        push!(poly_list_map,pmap)

        function run_inpolygon(pt)
            polyg = [[first(i),last(i)] for i in coordlist]
            push!(polyg,polyg[1])
            return inpolygon(pt,polyg)
        end
        
        formatted_coords = hcat([first(i) for i in coordlist],[last(i) for i in coordlist])
        min_x = minimum(formatted_coords[:,1])
        max_x = maximum(formatted_coords[:,1])
        min_y = minimum(formatted_coords[:,2])
        max_y = maximum(formatted_coords[:,2])

        formatted_boxdata = []
        for (x,y) in zip(imcoords[:,1],imcoords[:,2])
            if x>min_x && x<max_x && y>min_y && y<max_y
                push!(formatted_boxdata,[x,y])
            end
        end
        inside_test = run_inpolygon.(formatted_boxdata)

        selection = [(i[1],i[2]) for i in formatted_boxdata[inside_test.==1]]
        formatted_boxdata = []

        selected_spectra = lift(spectra_select) do x
            zeros(length(selection),size(x,3))
        end

        @lift(for i in eachindex(selection)
            $(selected_spectra)[i,:] = $(spectra_select)[selection[i]...,:]
        end)

        μ = @lift(vec(mean($(selected_spectra),dims=1)))
        σ = @lift(vec(std($(selected_spectra),dims=1)))

        al_std = band!(ax_spec,λ_select,@lift($μ.-$σ),@lift($μ.+$σ),color=palette("Set1",9)[area_spectra_num],alpha=0.3)
        
        al = lines!(ax_spec,λ_select,μ,color=area_spectra_num,colormap=:Set1_9,colorrange=(1,9))

        
        push!(allist,al)
        push!(allist_std,al_std)
        coordlist = []
    end

    on(b_clear.clicks) do x
        for s in slist_rfl
            delete!(f_rfl.content[2],s)
        end
        for s in slist_map
            delete!(f_map.content[2],s)
        end
        for p in poly_list
            delete!(f_rfl.content[2],p)
        end
        for p in poly_list_map
            delete!(f_map.content[2],p)
        end
        for ps in pslist
            delete!(f_rfl.content[2],ps)
        end
        for pl in pllist
            delete!(ax_spec,pl)
        end
        for al in allist
            delete!(ax_spec,al)
        end
        for al_std in allist_std
            delete!(ax_spec,al_std)
        end

        slist_rfl = []
        slist_map = []
        poly_list = []
        poly_list_map = []
        pslist = []
        pllist = []
        allist = []
        allist_std=[]
        coordlist = []
    end

    display(GLMakie.Screen(),f_spec)
end

end #JenviGUI