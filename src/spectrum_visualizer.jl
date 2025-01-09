"""
Controls:
Enter Visualize Spectra Mode (m)
Exit Visualize Spectra Mode (l)
Get Spectrum (left click)
Collect Spectrum (double left click)
Average Current Collection (a)
"""

@kwdef mutable struct PointSpectra
    cube_size :: Tuple{Int64,Int64,Int64}
    collect_pointspec :: Bool = false
    test_coord:: Observable{GLMakie.Point{2,Int}} = Observable(GLMakie.Point{2,Int}(cube_size[1]÷2,cube_size[2]÷2))
    spec_coord:: Observable{GLMakie.Point{2,Int}} = Observable(GLMakie.Point{2,Int}(cube_size[1]÷2,cube_size[2]÷2))
    img_axis:: Axis
    tracking_coord:: Observable{GLMakie.Point{2,Float64}} = Observable(GLMakie.Point{2,Float64}(cube_size[1]/2,cube_size[2]/2))
    tracking_lines:: Vector{Plot} = Vector{Plot}(undef,2)
    nspec :: Int = 0
    cmap :: Symbol = :tab10
    maxspec :: Int = 10
    spec_pts :: Vector{Plot} = []
    collected_spec :: Vector{Plot} = []
    collected_spec_data :: Array{<:AbstractFloat,2} = Array{AbstractFloat}(undef,0,cube_size[3])
    collected_spec_pts :: Vector{GLMakie.Point{2,Int}} = Vector{GLMakie.Point{2,Int}}(undef,0)
    mark_size :: Observable{Float64} = Observable(10)
    ttip :: Plot{tooltip} = tooltip!(img_axis,0,0,"")
end

function Makie.process_interaction(interaction::PointSpectra, event::MouseEvent, axis)
    if event.type === MouseEventTypes.over && interaction.collect_pointspec
        pt = round.(Int,event.data) .+ 0.5
        interaction.tracking_coord[] = pt
    end
    if event.type === MouseEventTypes.leftclick && interaction.collect_pointspec
        pt = round.(Int,event.data)
        println("($(pt[1]),$(pt[2])) Selected!")
        interaction.test_coord[] = pt
    end
    
    if event.type === MouseEventTypes.leftdoubleclick && interaction.collect_pointspec
        interaction.nspec += 1
        pt = round.(Int,event.data)
        s = scatter!(interaction.img_axis,pt,color=interaction.nspec,colormap=interaction.cmap,colorrange=(1,interaction.maxspec),marker=:cross, markersize=interaction.mark_size,glowcolor=(:black,2),glowwidth=2)
        push!(interaction.spec_pts,s)
        interaction.spec_coord[] = pt
    end

end

function spectrum_visualizer(
    fig:: Figure, 
    h5file:: String, 
    name_vec:: Vector{String},
    collect_idx:: Int,
    legend_strings ::Vector{String}, 
    symb::Symbol, 
    wavelength_path:: String; 
    flip_image::Bool = false, save_file::String="save.txt",overwrite_save::Bool=true, ax_title::String = "", plotspx::Union{Nothing,Vector{<:Dict}}= nothing
)

    img_axis = fig.content[1]
    f = Figure(size=(1500,500))
    spec_aspect = 5/4

    save_grid = f[2,1] = GridLayout()
    b = Button(save_grid[1,1],label = "Write Spectrum",tellwidth=false)
    b1 = Button(save_grid[1,2],label="Write Spectra",tellwidth=false)
    b2 = Button(f[2,2],label="Reset",tellwidth=false)

    if !isfile(save_file) || overwrite_save
        open(save_file,"w") do io
        end
    end

    spec_data, wvl = h5open(h5file) do f
        dsize = size(f[name_vec[1]])
        spec_data = Array{Float64}(undef,dsize...,0)
        for name in name_vec
            spcd = f[name][:,:,:]
            if flip_image
                spec_data = cat(spec_data,spcd[:,end:-1:1,:],dims=4)
            else
                spec_data = cat(spec_data,spcd[:,:,:],dims=4)
            end
        end
        return spec_data,attrs(f)[wavelength_path]
    end

    msize_sl = Slider(fig[5,1],range=5:0.1:20,startvalue=10)

    mypointspec = PointSpectra(cube_size = size(spec_data)[1:3],img_axis=img_axis,mark_size=msize_sl.value)

    spec_axis = Axis(f[1,1],title= ax_title,aspect=spec_aspect)
    clct_title = Observable(0)
    collect_axis = Axis(f[1,2],title=@lift(string($clct_title)*" Spectra Collected"),aspect=spec_aspect)
    avg_axis = Axis(f[1,3],aspect=spec_aspect)

    on(events(img_axis).keyboardbutton) do event
        if event.key == Keyboard.m && event.action == Keyboard.press
            mypointspec.collect_pointspec = true
            v = vlines!(mypointspec.img_axis,@lift($(mypointspec.tracking_coord)[1]),1,mypointspec.cube_size[2],color=:red)
            h = hlines!(mypointspec.img_axis,@lift($(mypointspec.tracking_coord)[2]),1,mypointspec.cube_size[1],color=:red)
            mypointspec.tracking_lines = [v,h]
            tt_string = @lift(string($(mypointspec.tracking_coord).-0.5))
            println(tt_string)
            tt = tooltip!(mypointspec.img_axis,mypointspec.tracking_coord,tt_string)
            mypointspec.ttip = tt
        end
        if event.key == Keyboard.l && event.action == Keyboard.press
            mypointspec.collect_pointspec = false
            for i in mypointspec.tracking_lines
                delete!(mypointspec.img_axis,i)
            end
        end
        if event.key == Keyboard.a && event.action == Keyboard.press

            avg = mean(mypointspec.collected_spec_data,dims=1)

            lines!(avg_axis,wvl,vec(avg),label=string(size(mypointspec.collected_spec_data,1))*" Spectra")
            mypointspec.collected_spec_data = Array{AbstractFloat}(undef,0,mypointspec.cube_size[3])
            empty!(collect_axis)
            # axislegend(avg_axis,position=:lt)
        end
    end

    plotted_spec = Vector{Observable}(undef,size(spec_data,4))
    for i = axes(spec_data,4)
        spec = @lift(spec_data[$(mypointspec.test_coord)...,:,i])
        if isnothing(plotspx)
            lines!(spec_axis,wvl,spec,label=legend_strings[i])
        else    
            lines!(spec_axis,wvl,spec,label=legend_strings[i]; plotspx[i]...)
        end
        # scatter!(spec_axis,wvl,spec,marker=:circle,color=:black,markersize=5)
        plotted_spec[i] = spec
    end

    on(mypointspec.test_coord) do ob
        ma = max([maximum(to_value(i)) for i in plotted_spec]...)
        mi = min([minimum(to_value(i)) for i in plotted_spec]...)
        ylims!(spec_axis,mi-(0.1*mi),ma+(0.1*ma))
        # println(spec_data[to_value(mypointspec.test_coord)...,1:10,1])
        # println(spec_data[to_value(mypointspec.test_coord)...,1:10,2])
    end

    on(mypointspec.spec_coord) do ob
        selected_spec = spec_data[to_value(mypointspec.spec_coord)...,:,collect_idx]
        cs = lines!(collect_axis,wvl,selected_spec,color=mypointspec.nspec,colormap=mypointspec.cmap,colorrange=(1,mypointspec.maxspec))
        reset_limits!(collect_axis)
        push!(mypointspec.collected_spec,cs)
        selected_spec_r = reshape(selected_spec,1,size(selected_spec)...)
        mypointspec.collected_spec_data = cat(mypointspec.collected_spec_data,selected_spec_r,dims=1)
        push!(mypointspec.collected_spec_pts,(to_value(mypointspec.spec_coord)))
        clct_title[] = length(mypointspec.collected_spec)
    end

    on(b.clicks) do f
        open(save_file,"a") do io
            println(io,to_value(@lift(spec_data[$(mypointspec.spec_coord)...,:,1])))
        end
        println("Spectrum saved to $save_file")
        scatter!(img_axis,to_value(mypointspec.spec_coord),marker=:star6,markersize=20)
    end

    on(b1.clicks) do f
        open(save_file,"a") do io
            for (n,row) in enumerate(eachrow(mypointspec.collected_spec_data))
                println(io,row," $(mypointspec.collected_spec_pts[n])")
            end
        end
        println("Spectra saved to $save_file","  ",size(mypointspec.collected_spec_data))
    end

    on(b2.clicks) do f
        for i in mypointspec.collected_spec
            delete!(collect_axis,i)
        end
        for j in mypointspec.spec_pts
            delete!(mypointspec.img_axis,j)
        end
        mypointspec.spec_pts = []
        mypointspec.collected_spec = []
        mypointspec.collected_spec_data = []
        mypointspec.nspec = 0
    end

    axislegend(spec_axis,position=:lt)

    try
        register_interaction!(img_axis, symb, mypointspec)
    catch
        deregister_interaction!(img_axis,symb)
        register_interaction!(img_axis, symb, mypointspec)
    end
    
    # DataInspector(f)
    display(GLMakie.Screen(),f)

    return f
end