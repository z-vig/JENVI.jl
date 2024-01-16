#JenviGUI.jl
module JenviGUI
export ask_file,build_gui,init_fig,init_obs,imageviewer,histogramviewer,spectralviewer

using GLMakie
using StatsBase
using PolygonOps
using Gtk4

function ask_file(start_folder::String)
    path = open_dialog("Select Image to Visualize",start_folder=start_folder)
    if isfile(path)
        return path
    else
        println("Please Select a file")
    end
end

function init_fig()
    f_image = Figure()
    f_histogram = Figure()
    f_spectra = Figure()
    return f_image,f_histogram,f_spectra
end

function init_obs(image::Array{<:AbstractFloat,3},spec::Array{<:AbstractFloat,3},wvl_vals::Vector{Float64},figure_list::Vector{Figure})
    f_image,f_histogram,f_spectra = figure_list

    band_slider = Slider(f_image[2,1],range=range(1,size(image,3)),startvalue=size(image,3),tellwidth=false)
    
    band_string = lift(band_slider.value) do val
        "Showing $(wvl_vals[val]) nm band"
    end

    band_image = lift(band_slider.value) do val
        image[:,:,val]
    end

    histdata = lift(band_slider.value) do val
        vec(image[:,:,val])
    end

    hist_slider = IntervalSlider(f_hist[2,1],range=range(minimum(histdata),maximum(histdata),100),startvalues=(percentile(histdata,1),percentile(histdata,99)))

    imstretch = lift(hist_slider.interval) do inter
        inter
    end

    obs_dict::Dict{String,Observable} = Dict(
        "band_string"=>band_string,
        "band_image"=>band_image,
        "histdata"=>histdata,
        "imstretch"=>imstretch
        )

    return obs_dict

end

function imageviewer(image::Array{<:AbstractFloat,3},fig_list::Vector{Figure},obs_dict::Dict{String,Observable})
    ax_im = GLMakie.Axis(f_image[1,1])
    ax_im.title = "Reflectance Image"

    band_string = lift(sl.value) do val
        "Showing $(wvl_vals[val]) nm band"
    end

    im = image!(ax_im,band_im,colorrange=imstretch,interpolate=false)

    Label(f_image[3,1],band_string,tellwidth=false)

    return f_image
end

function histogramviewer(image::Array{<:AbstractFloat,3},fig_list::Vector{Figure},obs_dict::Dict{String,Observable})
    f_hist = Figure()
    ax_hist = GLMakie.Axis(f_hist[1,1])

    histdata = vec(image)

    sl_exp = IntervalSlider(f_hist[2,1],range=range(minimum(histdata),maximum(histdata),100),startvalues=(percentile(histdata,1),percentile(histdata,99)))

    imstretch = lift(sl_exp.interval) do inter
        inter
    end
   
    bin_width = 2*iqr(histdata)/(length(histdata))^(1/3)
    bin_list = minimum(histdata):bin_width:maximum(histdata)
    bin_avg = [(bin_list[i]+bin_list[i+1])/2 for i ∈ eachindex(bin_list[1:end-1])]
    
    clist = lift(sl_exp.interval) do inter
        map(bin_avg) do val
            inter[1] < val < inter[2]
        end
    end

    hist!(ax_hist,histdata,bins=bin_list,color=clist,colormap=[:transparent,:red],strokewidth=0.1)

    return f_hist,imstretch
end

function spectralviewer(spec_datasets::Vector{Array{<:AbstractFloat,3}},λs::Vector{Vector{Float64}})

end

function build_gui(image_arr::Array{<:AbstractFloat,3},spec_arr::Array{<:AbstractFloat,3},wvl_vals::Vector{Float64})
    im = image_arr[:,:,200]
    imcoords = vec([[x,y] for x in 1:size(im,1),y in 1:size(im,2)])
    imcoords = hcat([i[1] for i in imcoords],[i[2] for i in imcoords])

    f_image = Figure()
    ax_im = GLMakie.Axis(f_image[1,1])
    ax_im.title = "Reflectance Image"

    f = Figure(size=(750,450))

    ax1 = GLMakie.Axis(f[1,1])
    ax2 = GLMakie.Axis(f[1,2])
    
    histdata = vec(im)

    sl_exp = IntervalSlider(f[2,1],range=range(minimum(histdata),maximum(histdata),100),startvalues=(percentile(histdata,1),percentile(histdata,99)))

    imstretch = lift(sl_exp.interval) do inter
        inter
    end
   
    bin_width = 2*iqr(histdata)/(length(histdata))^(1/3)
    bin_list = minimum(histdata):bin_width:maximum(histdata)
    bin_avg = [(bin_list[i]+bin_list[i+1])/2 for i ∈ eachindex(bin_list[1:end-1])]
    
    clist = lift(sl_exp.interval) do inter
        map(bin_avg) do val
            inter[1] < val < inter[2]
        end
    end

    hist!(ax1,histdata,bins=bin_list,color=clist,colormap=[:transparent,:red],strokewidth=0.1)
    im = image!(ax_im,im,colorrange=imstretch,interpolate=false)

    pllist = []
    pslist = []
    num_spectra = 0
    register_interaction!(ax_im,:get_spectra) do event::MouseEvent,axis
        if event.type==MouseEventTypes.leftclick
            if num_spectra<10
                num_spectra += 1
            else
                num_spectra = 1
            end
            xpos = Int(round(event.data[1]))
            ypos = Int(round(event.data[2]))
            println("X:$xpos, Y:$ypos")
            pl = lines!(ax2,wvl_vals,spec_arr[xpos,ypos,:],color=num_spectra,colormap=:tab10,colorrange=(1,10),linestyle=:dash)
            ps = scatter!(ax_im,xpos,ypos,color=num_spectra,colormap=:tab10,colorrange=(1,10),markersize=5)
    
            push!(pllist,pl)
            push!(pslist,ps)
        end
    end

    slist = []
    coordlist::Vector{Tuple{Float64,Float64}} = []
    register_interaction!(ax_im,:area_spectra) do event::KeysEvent, axis
        if all([i in event.keys for i in [Keyboard.q,Keyboard.left_shift]])
            mp = mouseposition(ax_im)
            xpos = mp[1]
            ypos = mp[2]
            s = scatter!(ax_im,xpos,ypos,color=:Red)
            push!(slist,s)
            push!(coordlist,(xpos,ypos))
        end
    end

    f_image[2, 1] = buttongrid = GridLayout(tellwidth = false)
    poly_list = []

    b_select = Button(f_image,label="Plot Selection")
    b_clear = Button(f_image,label="Clear Selection")
    buttongrid[1,1:2] = [b_select,b_clear]

    area_spectra_num = 0
    allist = []
    on(b_select.clicks) do x
        if area_spectra_num<10
            area_spectra_num += 1
        else
            area_spectra_num = 1
        end

        for s in slist
            s.color = :transparent
        end
        println(length(coordlist))
        p = poly!(ax_im,coordlist,strokewidth=1,color=area_spectra_num,colormap=:tab10,colorrange=(1,10),alpha=0.5)
        push!(poly_list,p)

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

        selected_spectra = zeros(length(selection),239)
        for i in eachindex(selection)
            selected_spectra[i,:] = spec_arr[selection[i]...,:]
        end
        #println(mean(selected_spectra,dims=1))
        al = lines!(ax2,wvl_vals,vec(mean(selected_spectra,dims=1)),color=area_spectra_num,colormap=:tab10,colorrange=(1,10))
        
        push!(allist,al)
        coordlist = []
        
    end

    on(b_clear.clicks) do x
        for s in slist
            delete!(ax_im,s)
        end
        for p in poly_list
            delete!(ax_im,p)
        end
        for ps in pslist
            delete!(ax_im,ps)
        end
        for pl in pllist
            delete!(ax2,pl)
        end
        for al in allist
            delete!(ax2,al)
        end

        slist = []
        poly_list = []
        pslist = []
        pllist = []
        allist = []
        coordlist = []
    end
    
    butt = Button(f[2,2],label="Reset",tellwidth=false)
    on(butt.clicks) do click
        empty!(ax2)
    end
    display(GLMakie.Screen(),f_image)
    display(GLMakie.Screen(),f)

    return f_image,f
end


end #JenviGUI