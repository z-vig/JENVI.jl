module GUIObservables

using GLMakie
export init_obs

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

end #GUIObservables