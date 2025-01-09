"""
Enter Mixture Visualization Mode (m)
"""

struct MixModelResults
    dat :: Array{Float64,3} #(X x Y x N) image cube
    frc :: Array{Float64,3} #(X x Y x P) array where P is # of endmembers
    res :: Matrix{Float64} #(X x Y) matrix of model resdiuals
    mem :: Matrix{Float64} #(N x P) matrix of endmembers
    λ :: Vector{Float64} #N length vector of wavelengths
    names :: Vector{String} #P length vector of endmember names
    coords :: Vector{Tuple{Int,Int}} #P length vector of endmember coords
end

function get_results(h5file::String,model_id::String;flip_image::Bool=true) :: MixModelResults
    return h5open(h5file) do f
        d1 = f["$model_id/data"][:,:,:]
        d2 = f["$model_id/fractions"][:,:,:]
        d3 = f["$model_id/residuals"][:,:]
        d4 = f["$model_id/endmembers"][:,:]
        if flip_image
            d1 = d1[:,end:-1:1,:]
            d2 = d2[:,end:-1:1,:]
            d3 = d3[:,end:-1:1]
            d4 = d4[:,:]
        end
        mmr = MixModelResults(
            d1,d2,d3,d4,
            attrs(f)["wavelengths"],
            attrs(f["$model_id"])["endmember_names"],
            Tuple.(attrs(f["$model_id"])["endmember_coords"])
        )
        return mmr
    end
end

@kwdef mutable struct PointMix
    cube_size :: Tuple{Int64,Int64,Int64}
    img_axis :: Axis
    collect_point :: Bool = false
    view_coord:: Observable{GLMakie.Point{2,Int}} = Observable(GLMakie.Point{2,Int}(cube_size[1] ÷ 2, cube_size[2] ÷ 2))
    tracking_coord:: Observable{GLMakie.Point{2,Float64}} = Observable(GLMakie.Point{2,Float64}(cube_size[1]/2,cube_size[2]/2))
    tracking_lines:: Vector{Plot} = Vector{Plot}(undef,2)
    tracking_tooltip:: Plot{tooltip} = tooltip!(img_axis,0,0,"")
    spec:: Plot{lines} = lines!(img_axis,zeros(cube_size[3]))
    mix:: Plot{barplot} = barplot!(img_axis,zeros(2))
end

function Makie.process_interaction(interaction::PointMix, event::MouseEvent, axis)
    #Tracking mouse in collect mode
    if event.type === MouseEventTypes.over && interaction.collect_point
        pt = round.(Int,event.data) .+ 0.5
        interaction.tracking_coord[] = pt
        interaction.view_coord[] = round.(Int,pt)
    end
    #Plotting point when left clicked
    if event.type === MouseEventTypes.leftclick && interaction.collect_point
        pt = round.(Int,event.data)
        println("($(pt[1]),$(pt[2])) Selected!")
        interaction.view_coord[] = pt
    end
end

function mixture_visualizer(
    fig:: Figure, 
    h5file:: String,
    model_id:: String,
    symb::Symbol,
    ;flip_image::Bool = false
)
    img_axis = fig.content[1]

    mmr = get_results(h5file,model_id,flip_image=flip_image)
    pm = PointMix(cube_size = size(mmr.dat), img_axis = img_axis)

    f = Figure(size=(1500,500))
    fgl = f[1,1] = GridLayout()
    lgl = fgl[1,1] = GridLayout()
    sgl = fgl[1,2] = GridLayout()
    colsize!(fgl,1,Relative(1/10))
    spec_aspect = 5/4
    spec_axis = Axis(sgl[1,1],aspect=spec_aspect)
    mix_axis = Axis(sgl[1,2],aspect=spec_aspect,xticks=(1:length(mmr.names),mmr.names),xticklabelrotation=π/4)

    mem_list = []
    for i in axes(mmr.mem,2)
        lin = lines!(spec_axis,mmr.λ,mmr.mem[:,i],color=i,colorrange=(1,10),colormap=:tab10,linestyle=:solid,alpha=0.4,label=mmr.names[i])
        push!(mem_list,lin)
    end
    Legend(lgl[2,1],mem_list,mmr.names,title="Endmembers")
    colsize!(lgl,1,Relative(1/12))

    on(events(img_axis).keyboardbutton) do event
        if event.key == Keyboard.m && event.action == Keyboard.press && pm.collect_point == false
            delete!(pm.img_axis,pm.tracking_tooltip)
            pm.collect_point = true
            v = vlines!(pm.img_axis,@lift($(pm.tracking_coord)[1]),1,pm.cube_size[2],color=:red)
            h = hlines!(pm.img_axis,@lift($(pm.tracking_coord)[2]),1,pm.cube_size[1],color=:red)
            pm.tracking_lines = [v,h]

            tt_string = @lift(string($(pm.view_coord))*"\n")
            for (n,i) in enumerate(mmr.names)
                tt_string = @lift($tt_string * string(i) * ": " * string(round(mmr.frc[$(pm.view_coord)...,n],digits=2)) * "\n")
            end
            tt = tooltip!(pm.img_axis,pm.view_coord,tt_string)
            pm.tracking_tooltip = tt

            plot_spectrum = lines!(spec_axis,mmr.λ,@lift(mmr.dat[$(pm.view_coord)...,:]),label="Data",color=:black)
            pm.spec = plot_spectrum
            
            model_spec = @lift(mmr.mem * mmr.frc[$(pm.view_coord)...,:])
            plot_model = lines!(spec_axis,mmr.λ,model_spec,label="Model",color=:red)

            mix_nums = @lift(mmr.frc[$(pm.view_coord)...,:])
            bp = barplot!(mix_axis,1:length(mmr.names),mix_nums,color=1:length(mmr.names),colormap=:tab10,colorrange=(1,20),label_rotation=45)
            pm.mix = bp
            Legend(lgl[1,1],[plot_spectrum,plot_model],["Data","Model"])
        end
        if event.key == Keyboard.l && event.action == Keyboard.press
            pm.collect_point = false
            for i in pm.tracking_lines
                delete!(pm.img_axis,i)
            end
            delete!(pm.img_axis,pm.tracking_tooltip)
        end
    end

    on(pm.tracking_coord) do f
        reset_limits!(spec_axis)
        reset_limits!(mix_axis)
    end

    try
        register_interaction!(img_axis, symb, pm)
    catch
        deregister_interaction!(img_axis,symb)
        register_interaction!(img_axis, symb, pm)
    end
    
    # DataInspector(f)
    display(GLMakie.Screen(),f)

    return fig
end