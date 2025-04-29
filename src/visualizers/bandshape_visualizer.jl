"""
    GUIGridLayouts(f)

Holds all of the Grid Layouts for the GUI
"""
struct GUIGridLayouts
    f::Figure
    left_gl::GridLayout
    right_gl::GridLayout
    img_gl::GridLayout
    bandsel_gl::GridLayout
    hist_gl::GridLayout
    interval_gl::GridLayout
    band_gl::GridLayout
    band_buttons_gl::GridLayout
    spectrum_gl::GridLayout
    specinterval_gl::GridLayout

    function GUIGridLayouts()
        f = Figure(size=(1250, 700))

        left_gl = f[1, 1] = GridLayout()

        img_gl = left_gl[1, 1] = GridLayout()
        bandsel_gl = img_gl[10, 1] = GridLayout()

        hist_gl = left_gl[2, 1] = GridLayout()
        interval_gl = hist_gl[2, 1] = GridLayout()

        right_gl = f[1, 2] = GridLayout()

        band_gl = right_gl[1:3, 1] = GridLayout()
        band_buttons_gl = band_gl[10, 1] = GridLayout()

        spectrum_gl = right_gl[4, 1] = GridLayout()
        specinterval_gl = spectrum_gl[2, 1] = GridLayout()

        new(f, left_gl, right_gl, img_gl, bandsel_gl,
            hist_gl, interval_gl, band_gl, band_buttons_gl,
            spectrum_gl, specinterval_gl)
    end
end

"""
    BandImageBlocks(ggl,imcube_size,λ)

Axis and blocks for Band Image
"""
mutable struct BandImageBlocks
    ggl::GUIGridLayouts
    imcube_size::Tuple{Real,Real,Real}
    λ::Vector{Float64}
    axis::Axis 
    bandselect::Slider
    bandselectlabel::Label

    function BandImageBlocks(
        ggl::GUIGridLayouts,
        imcube_size::Tuple{Real, Real, Real},
        λ::Vector{Float64}
    )
        axis = Axis(ggl.img_gl[1:end-1, 1])
        axis.aspect = DataAspect()

        bandselect = Slider(
            ggl.bandsel_gl[2,1],
            range=1:imcube_size[3],
            startvalue=1,
            tellwidth=true,
            height=50
        )
        bandselectlabel = Label(
            ggl.bandsel_gl[1, 1],
            @lift(
                string(
                    "Wavelength: ",
                    round(λ[$(bandselect.value)],digits=2)
                )
            ),
            tellwidth=false
        )
        new(
            ggl, imcube_size, λ, axis, bandselect, bandselectlabel
        )
    end
end

"""
    HistogramBlocks(ggl,hist_data)

Axis and blocks for histogram
"""
mutable struct HistogramBlocks{T<:AbstractFloat}
    ggl::GUIGridLayouts
    hist_data::Observable{Vector{AbstractFloat}}
    axis::Axis
    histselect::IntervalSlider 
    histlabel::Label
    h::Observable
    hist_colors::Observable

    function HistogramBlocks{T}(
        ggl::GUIGridLayouts,
        hist_data::Observable{Vector{T}}
    ) where {T<:AbstractFloat}
        axis = Axis(ggl.hist_gl[1,1])

        histselect = IntervalSlider(
            ggl.interval_gl[2,1],
            range=@lift(minimum($hist_data):0.01:maximum($hist_data)),
            startvalues=@lift((minimum($hist_data),maximum($hist_data))),
            height=50
        )

        histlabel = Label(
            ggl.interval_gl[1,1],
            @lift(
                string(
                    "Min: ",
                    round($(histselect.interval)[1],digits=2),
                    "  Max: ",
                    round($(histselect.interval)[2],digits=2)
                )
            ),
            tellwidth=false
        )

        h = @lift(StatsBase.fit(Histogram, $hist_data, nbins=100))

        hist_colors = @lift(
            [
                val > $(histselect.interval)[1] &&
                val < $(histselect.interval)[2] ?
                :red : :transparent
                for val in $h.edges[1]
            ]
        )
    
        return new(
            ggl, hist_data, axis, histselect,
            histlabel, h, hist_colors
        )
    end
end
HistogramBlocks(
    ggl::GUIGridLayouts,
    hist_data::Observable{Vector{Float64}}
) = HistogramBlocks{Float64}(ggl, hist_data)

mutable struct SpecBlocks
    ggl::GUIGridLayouts
    λ::Vector{Float64}
    axis::Axis
    specinterval:: IntervalSlider
    speclabel:: Label
    bdmap_axis::Axis

    function SpecBlocks(
        ggl::GUIGridLayouts,
        λ::Vector{Float64},
    )
        axis = Axis(ggl.spectrum_gl[1, 1])

        specinterval = IntervalSlider(
            ggl.specinterval_gl[2, 1],
            range=minimum(λ):0.001:maximum(λ),
            tellwidth=false
        )

        speclabel = Label(
            ggl.specinterval_gl[1, 1],
            @lift(
                string(
                    "Min: ",
                    round($(specinterval.interval)[1],digits=2),
                    "  Max: ",
                    round($(specinterval.interval)[2],digits=2)
                )
            ),
            tellwidth=false
        )

        bdmap_axis = Axis(ggl.band_gl[1:end-1, 1])
        bdmap_axis.aspect = DataAspect()

        new(
            ggl, λ, axis, specinterval, speclabel, bdmap_axis
        )
    end
end

function observer_functions(ggl,bib,hb,sb,ip)
    on(bib.bandselect.value) do o
        reset_limits!(hb.axis)
    end
    on(ip.coord) do o
        reset_limits!(sb.axis)
    end
end

"""
    BandShape(pos)

Struct for storing interactive plot information related to band shape
visualization. Simply initialize with no arguments and access fields as needed.

# Arguments
nothing

# Fields
- `active`: Active state variable
- `pos`: Current position of the cursor 
- `coord`: Coordinate of cursor
- `pmap`: Position map
"""
mutable struct InteractivePlot{T<:AbstractFloat}
    active::Bool
    pos::Observable{GLMakie.Point{2,Float64}}
    coord::Observable{GLMakie.Point{2,Int}}
    pmap::Matrix{T}

    function InteractivePlot{T}() where {T<:AbstractFloat}

        active = false
        pos = Observable(GLMakie.Point{2,Float64}(1.0, 1.0))
        coord = Observable(GLMakie.Point{2,Int}(1,1))
        pmap = Array{Float64}(undef,0,0)

        new{T}(active, pos, coord, pmap)
    end
end
InteractivePlot() = InteractivePlot{Float64}()

"""
    adjust_layout(ggl)

Adjust the aspect ratios of plots in the GUI
"""
function adjust_layout(ggl::GUIGridLayouts;img_aspect::Real=0.5)

    rowsize!(ggl.left_gl,2,Aspect(1,0.3))
    rowsize!(ggl.left_gl,1,Aspect(1,1))

    rowsize!(ggl.bandsel_gl,2,Aspect(1,0.001))
    rowsize!(ggl.bandsel_gl,1,Aspect(1,0.01))

    # rowsize!(ggl.img_gl,2,Aspect(1,0.1))
    # rowsize!(ggl.img_gl,1,Aspect(1,img_aspect))

    rowsize!(ggl.hist_gl,2,Aspect(1,0.05))
    rowsize!(ggl.hist_gl,1,Aspect(1,0.1))

    rowsize!(ggl.interval_gl,2,Aspect(1,0.001))
    rowsize!(ggl.interval_gl,1,Aspect(1,0.01))
end

function Makie.process_interaction(
    interaction::InteractivePlot,
    event::MouseEvent, 
    axis
)
    # println(event.type)
    if event.type === MouseEventTypes.over && interaction.active
        pt = event.data
        coord = round.(Int,pt)
        interaction.pos[]=pt
        interaction.coord[]=coord
    end
end

function bandshape_interactions(
    ip::InteractivePlot,
    ggl::GUIGridLayouts,
    bib::BandImageBlocks,
    hb::HistogramBlocks,
    sb::SpecBlocks
)
    hlines!(bib.axis,@lift($(ip.pos)[2]);xmax=bib.imcube_size[2],color=:red)
    vlines!(bib.axis,@lift($(ip.pos)[1]);ymax=bib.imcube_size[1],color=:red)
end

"""
    bandshape_visualizer(h5loc)

Helps visualize and map spectral band shapes including band depth and band
center position

# Arguments
- `h5loc::AbstractH5ImageLocation`: See `AbstractH5ImageLocation.jl`.
- `flip_image::Bool`: If true, flips the image along vertical axis.
                      Default option is true.
"""
function bandshape_visualizer(
    h5loc::T;
    flip_image::Bool = false
)  :: Nothing where {T<:AbstractH5ImageLocation}

    imcube,λ = h5open(h5loc.path) do f
        if flip_image
            im = f[h5loc.data][:,:,:]
            return im[:,end:-1:1,:],attrs(f)[h5loc.lbl]
        else
            return f[h5loc.data][:,:,:],attrs(f)[h5loc.lbl]
        end
    end

    ip = InteractivePlot()
    ggl = GUIGridLayouts()
    bib = BandImageBlocks(ggl, size(imcube), λ)
    hidedecorations!(bib.axis)
    sb = SpecBlocks(ggl, λ)
    hidedecorations!(sb.bdmap_axis)

    imcube_obs = @lift(imcube[:,:,$(bib.bandselect.value)])
    hist_data = @lift($imcube_obs[isfinite.($imcube_obs)])
    println(typeof(ggl))
    hb = HistogramBlocks(ggl, hist_data)
    hidedecorations!(hb.axis)

    hist!(
        hb.axis,
        hist_data,
        bins=@lift(length($(hb.hist_colors))),
        color=hb.hist_colors,
        strokewidth=0.5,
        strokecolor=:black
    )

    image!(
        bib.axis,
        imcube_obs,
        colorrange=hb.histselect.interval,
        interpolate=false
    )

    sp₀ = @lift(imcube[$(ip.coord)...,:])
    lines!(sb.axis,λ,sp₀)
    vlines!(
        sb.axis,
        @lift([$(sb.specinterval.interval)...]),
        ymin=0, ymax=1, color=:red
    )

    low = @lift(findλ(λ,$(sb.specinterval.interval)[1]))
    high = @lift(findλ(λ,$(sb.specinterval.interval)[2]))
    bd = @lift(banddepth(λ,$sp₀,$low[2],$high[2]))
    areax_idx = @lift([$low[1],[i for i ∈ $low[1]:$high[1]]...,$high[1]])
    areapts = @lift([(λ[i],$sp₀[i]) for i in $areax_idx])

    m = @lift(
        ($areapts[1][2]-$areapts[end][2]) / ($areapts[1][1]-$areapts[end][1])
    )

    b = @lift($areapts[1][2]-$m*$areapts[1][1])
    line_pts = @lift(
        [($areapts[i][1],$m*$areapts[i][1]+$b)
        for i ∈ eachindex($areapts)]
    )
    scatter!(sb.axis,areapts)
    ablines!(sb.axis,b,m)
    scatter!(sb.axis,line_pts)

    bc = @lift(bandposition(λ,$sp₀,$low[2],$high[2]))

    lines!(sb.axis,@lift($bc.poly_x),@lift($bc.poly_y))
    vlines!(sb.axis,@lift($bc.bc),color=:red,linestyle=:dot)

    bd_val = Label(
        ggl.specinterval_gl[3,1],
        @lift(
            string(
                "Band Depth: ",
                round($bd,digits=2),
                "   Band Center: ",
                round($bc.bc,digits=2)
            )
        ),
        tellwidth=false
    )

    b1 = Button(
        ggl.band_buttons_gl[1,1], label="Make BD Map", tellwidth=false
    )
    b2 = Button(
        ggl.band_buttons_gl[1, 2], label="Make BC Map", tellwidth=false
    )
    b3 = Button(
        ggl.band_buttons_gl[1,3], label="Save Current Map", tellwidth=false
    )
    t1 = Textbox(
        ggl.band_buttons_gl[1, 4], placeholder="HDF5 Save Name...", width=100
    )

    on(b1.clicks) do n
        bd_arr = map(CartesianIndices(axes(imcube)[1:2])) do i
            x,y = Tuple(i)
            bd = banddepth(λ,imcube[x,y,:],to_value(low)[2],to_value(high)[2])
            return bd
        end
        ip.pmap = bd_arr
        crange = (
            quantile(vec(ip.pmap[isfinite.(ip.pmap)]), 0.25),
            quantile(vec(ip.pmap[isfinite.(ip.pmap)]), 0.75)
        )
        image!(sb.bdmap_axis,ip.pmap, colorrange=crange, interpolate=false)
        hlines!(
            sb.bdmap_axis,
            @lift($(ip.pos)[2]);
            xmax=bib.imcube_size[2], color=:red
        )
        vlines!(
            sb.bdmap_axis,
            @lift($(ip.pos)[1]);
            ymax=bib.imcube_size[1], color=:red
        )
    end

    on(b2.clicks) do n
        empty!(sb.bdmap_axis)

        rows, cols = size(imcube)[1:2]
        bc_arr = Matrix{Float64}(undef, rows, cols)
    
        low_val = to_value(low)[2]
        high_val = to_value(high)[2]
    
        @showprogress for i in CartesianIndices((rows, cols))
            x, y = Tuple(i)
            bc = bandposition(λ, imcube[x, y, :], low_val, high_val)
    
            if bc.bc == low_val || bc.bc == high_val
                bc_arr[x, y] = NaN
            else
                bc_arr[x, y] = bc.bc
            end
        end
    
        ip.pmap = bc_arr
        crange = (
            quantile(vec(ip.pmap[isfinite.(ip.pmap)]), 0.15),
            quantile(vec(ip.pmap[isfinite.(ip.pmap)]), 0.85)
        )
        image!(sb.bdmap_axis, ip.pmap, colorrange=crange, interpolate=false)
        hlines!(
            sb.bdmap_axis,
            @lift($(ip.pos)[2]);
            xmax=bib.imcube_size[2], color=:red
        )
        vlines!(
            sb.bdmap_axis,
            @lift($(ip.pos)[1]);
            ymax=bib.imcube_size[1], color=:red
        )
    end

    on(b3.clicks) do n
        @async begin
            save_path = open_dialog("Select HDF5 File to save data:")
            data_path = t1.stored_string[]
            h5open(save_path,"r+") do f
                safe_add_to_h5(f,data_path,ip.pmap)
            end
            println("File Saved at $data_path")
        end

        # println(save_path," ",data_path)
        # h5open("D:/HSI/hdf5_files/glass_mtn_data.hdf5","r+") do f
        #     f["BDMaps/8micron"] = ip.pmap
        # end
    end

    adjust_layout(ggl,img_aspect=size(imcube,1)/size(imcube,2))
    observer_functions(ggl,bib,hb,sb,ip)
    bandshape_interactions(ip,ggl,bib,hb,sb)

    try
        register_interaction!(bib.axis,:bs, ip)
    catch
        deregister_interaction!(bib.axis,:bs)
        register_interaction!(bib.axis,:bs, ip)
    end

    on(events(bib.axis).keyboardbutton) do event
        if event.key == Keyboard.m && event.action == Keyboard.press
            ip.active = true
        end
        if event.key == Keyboard.l && event.action == Keyboard.press
            ip.active = false
        end
    end

    DataInspector(ggl.f)
    display(GLMakie.Screen(),ggl.f)

    return nothing
end
