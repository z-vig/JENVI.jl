# image_visualizer.jl

# Finds the statistical range of a dataset, x
rangeof(x) = (tmp = extrema(x); return tmp[2] - tmp[1]) 

"
    ImageCubeData(
        im_array::Array{<:AbstractFloat}
        λ::Vector{<:AbstractFloat}
        selected_band::Observable{Int}
        color_map::Symbol
    )

Stores pertinent data from an image cube representing spectral data

# Fields
- `im_array`: 3 dimensional array of all the image data
- `λ`: Vector of band wavelengths
- `selected_band`: Observable for the currently examined image band
- `color_map`: The current color map for the image to be displayed by
- `display_matrix`: matrix of the image that is currently displayed (i.e. one
                   band of the `im_array`)
- `finite_data`: vector of all finite data in the currently displayed image
                (i.e. gets rid of NaN, inf, etc...)
- `histogram`: StatsBase.Histogram object for the finite data observable
- `color_range`: Tuple of th
"
mutable struct ImageCubeData
    im_array::Array{<:AbstractFloat}
    λ::Vector{<:AbstractFloat}
    selected_band::Observable{Int}
    color_map::Symbol
    display_matrix::Observable{Matrix{<:AbstractFloat}}
    display_mask::Observable{BitMatrix}
    finite_data::Observable{Vector{<:AbstractFloat}}
    histogram::Observable{StatsBase.Histogram}
    color_range::Observable{Tuple{<:AbstractFloat,<:AbstractFloat}}

    function ImageCubeData(
        im_array::Array{<:AbstractFloat},
        λ::Vector{<:AbstractFloat},
        selected_band::Observable{Int},
        color_map::Symbol
    )

        display_matrix = @lift(im_array[:,:,$selected_band])
        display_mask = @lift(isfinite.($display_matrix))
        finite_data = @lift($display_matrix[$display_mask])
        histogram = @lift(StatsBase.fit(Histogram,$finite_data,nbins=100))
        color_range = @lift(extrema($finite_data))

        new(
            im_array, λ, selected_band, color_map, display_matrix,
            display_mask, finite_data, histogram, color_range
        )

    end
end

mutable struct ImageRasterData
    im_array::Matrix{<:AbstractFloat}
    λ::Vector{<:AbstractFloat}
    color_map::Symbol
    display_matrix::Observable{Matrix{<:AbstractFloat}}
    display_mask::Observable{BitMatrix}
    finite_data::Observable{Vector{<:AbstractFloat}}
    histogram::Observable{StatsBase.Histogram}
    color_range::Observable{Tuple{<:AbstractFloat,<:AbstractFloat}}

    function ImageRasterData(
        im_array::Matrix{<:AbstractFloat},
        λ::Vector{<:AbstractFloat},
        color_map::Symbol,
    )
        display_matrix = Observable(im_array)
        display_mask = @lift(isfinite.($display_matrix))
        finite_data = @lift($display_matrix[$display_mask])
        histogram = @lift(StatsBase.fit(Histogram,$finite_data,nbins=100))
        color_range = @lift(extrema($finite_data))

        new(
            im_array, λ, selected_band, color_map, display_matrix,
            display_mask, finite_data, histogram, color_range
        )
    end
end

mutable struct ImageCubeLayout
    parent_figure::Figure
    imagegrid::GridLayout
    histogramgrid::GridLayout
    slidergrid::GridLayout
    buttongrid::GridLayout

    function ImageCubeLayout(parent_figure::Figure)

        imagegrid = parent_figure[1,1] = GridLayout()
        histogramgrid = parent_figure[2,1] = GridLayout()
        slidergrid = parent_figure[3,1] = GridLayout()
        buttongrid = parent_figure[4,1] = GridLayout()

        new(
            parent_figure, imagegrid, histogramgrid, slidergrid, buttongrid
        )
    end
end

@kwdef mutable struct ImageRasterLayout
    parent_figure::Figure
    imagegrid::GridLayout = parent_figure[1,1] = GridLayout()
    histogramgrid::GridLayout = parent_figure[2,1] = GridLayout()
    slidergrid::GridLayout = parent_figure[3,1] = GridLayout()
end

@kwdef mutable struct RGBLayout
    parent_figure::Figure
    imagegrid::GridLayout = parent_figure[1:20,1] = GridLayout()
    slidergrid::GridLayout = parent_figure[5,2] = GridLayout()
end

mutable struct ButtonSelector
    firstband::Button
    decrease::Button
    increase::Button
    lastband::Button
    jumpto::Textbox
end

function get_parent_fig()::Figure
    m1 = GLFW.GetPrimaryMonitor()
    vm = GLFW.GetVideoMode(m1)
    f = Figure(size=(vm.width/2,vm.height/2))
    return f
end

function adjust_parent_fig_cube(parent_figure::Figure) :: Nothing
    rowsize!(parent_figure.layout,1,Relative(5/7)) #Main Image Axis
    # rowsize!(parent_figure.layout,2,Relative(1/10)) #Hsitogram Axis
end

function adjust_parent_fig_rgb(parent_figure::Figure) :: Nothing
    colsize!(parent_figure.layout,1,Relative(5/7)) #Main Image Axis
end

function get_image_axis(parent_position::GridPosition)::Axis
    image_axis = Axis(parent_position,aspect=DataAspect())
    hidedecorations!(image_axis)
    # hidespines!(image_axis)
    return image_axis
end

function color_range_selector(
    parent_position::GridPosition,
    imdata::Union{ImageCubeData,ImageRasterData}
)::IntervalSlider
    r = @lift(range(extrema($(imdata.finite_data))...,100))
    isl = IntervalSlider(parent_position, range = r, tellwidth=true)
    return isl
end

function activate_color_range_selector!(
    isl::IntervalSlider,
    imdata::Union{ImageCubeData,ImageRasterData}
)::Nothing
    imdata.color_range = isl.interval
    return nothing
end

function band_selector(
    parent_figure::Figure,
    parent_position::GridPosition,
    imdata::ImageCubeData
) :: ButtonSelector
    b1 = parent_position[1,1] = Button(parent_figure,label="First Band")
    b2 = parent_position[1,2] = Button(parent_figure,label="Decrease Band")
    b3 = parent_position[1,3] = Button(parent_figure,label="Increase Band")
    b4 = parent_position[1,4] = Button(parent_figure,label="Last Band")
    parent_position[1,5] = Label(
        parent_figure,
        @lift(string("Band: ",$(imdata.selected_band)))
    )

    parent_position[1,6] = Label(
        parent_figure,
        @lift(string("Wavelengths: ",
                     round(imdata.λ[$(imdata.selected_band)],digits=2)
                    )
        )
    )

    b7 = parent_position[1,7] = Textbox(
        parent_figure, placeholder="Jump to band..."
    )

    return ButtonSelector(b1,b2,b3,b4,b7)
end

function activate_band_selector!(
    bs::ButtonSelector,
    imdata::ImageCubeData
)::Nothing
    nbands = size(imdata.im_array,3)
    on(bs.firstband.clicks) do n
        imdata.selected_band[] = 1
    end

    on(bs.decrease.clicks) do n
        if to_value(imdata.selected_band) >= 2
            imdata.selected_band[] -= 1
        end
    end

    on(bs.increase.clicks) do n
        if to_value(imdata.selected_band) <= nbands-1
            imdata.selected_band[] += 1
        end
    end

    on(bs.lastband.clicks) do n
        imdata.selected_band[] = nbands
    end

    on(bs.jumpto.stored_string) do s
        imdata.selected_band[] = parse(Float64, s)
    end
    return nothing
end

function band_histogram(
    parent_position::GridLayout,
    imdata::Union{ImageCubeData,ImageRasterData}
) :: Axis
    histogram_axis = Axis(parent_position[1,1])
    on(imdata.finite_data) do o
        reset_limits!(histogram_axis)
    end
    return histogram_axis
end

function activate_band_histogram!(
    hga::Axis,
    imdata::Union{ImageCubeData,ImageRasterData}
) :: Nothing
    hist_colors = @lift(
        [
            val > $(imdata.color_range)[1] && 
            val < $(imdata.color_range)[2] ? :red : :transparent 
            for val in $(imdata.histogram).edges[1]
        ]
    )

    hist!(
        hga, imdata.finite_data,
        bins=@lift(length($(hist_colors))),
        color=hist_colors,
        strokewidth=0.5,
        strokecolor=:black
    )
    return nothing
end

function band_colorbar(
    parent_position::GridLayout,
    imdata::Union{ImageCubeData,ImageRasterData}
) :: Colorbar
    cbar = ColonBar(
        parent_position, limits=imdata.color_range, colormap=colormap
    )
end

"""
    image_visualizer()

# Arguments
- `h5loc::H5FileLocation`: H5FileLocation object to display as an image
- `band`: initial band of the data to display
- `color_map`: Optional. Color map to display the data. Default is `:gray1`
- `flip_image`: Optional. Boolean for whether or not to flip the image on the
                y-axis. Often needed when reading from HDF5. Default is false.
- `rgb_bounds`: Optional. R, G amd B band color ranges as tuples in a vector.
                Default is `nothing`
"""
function image_visualizer(
    h5loc::T;
    band=nothing,
    color_map = :gray1,
    flip_image::Bool=false,
    markbadvals::Bool=false,
    axis_title::Union{String, Vector{String}}="Image Axis",
    rgb_bounds::Union{Nothing, Vector{Tuple{R, R}}}=nothing
) :: Figure where {T<:AbstractH5ImageLocation} where {R<:AbstractFloat}

    arr,lbls = h52arr(h5loc)

    if flip_image arr = arr[:,end:-1:1,:]
        @debug "image_visualizer has flipped the image."
    end

    f = get_parent_fig()

    band = Observable(band)

    if typeof(h5loc) == H5cube
        adjust_parent_fig_cube(f)

        if isnothing(band) println("Set the band!") end

        ivl = ImageCubeLayout(f)

        imdata = ImageCubeData(arr, lbls, band, color_map)

        image_axis = get_image_axis(ivl.imagegrid[1,1])
        if axis_title isa String
            image_axis.title = axis_title
        else
            title_string = @lift(axis_title[$band])
            on(title_string) do t
                image_axis.title = t
            end
        end

        bs = band_selector(f,ivl.buttongrid[1,1],imdata)
        activate_band_selector!(bs,imdata)
    
        isl = color_range_selector(ivl.slidergrid[1,1],imdata)
        activate_color_range_selector!(isl,imdata)
    
        hga = band_histogram(ivl.histogramgrid,imdata)
        activate_band_histogram!(hga,imdata)
        
        if markbadvals
            image!(
                image_axis,
                imdata.display_matrix,
                colorrange=(-0.1,1.1),
                lowclip=:blue,
                highclip=:red,
                interpolate=false,
                nan_color=:gray
            )
        else
            image!(
                image_axis,
                imdata.display_matrix,
                colorrange=imdata.color_range,
                interpolate=false,
                nan_color=:gray
            )
        end
    end

    if typeof(h5loc) == H5rgb
        adjust_parent_fig_rgb(f)

        red_real = arr[isfinite.(arr[:,:,1]),1]
        green_real = arr[isfinite.(arr[:,:,2]),2]
        blue_real = arr[isfinite.(arr[:,:,3]),3]
        
        rgbl = RGBLayout(parent_figure = f)

        image_axis = get_image_axis(rgbl.imagegrid[1,1])

        if isnothing(rgb_bounds)
            rgb_bounds = [
                extrema(red_real) .* 0.8,
                extrema(green_real) .* 0.8,
                extrema(blue_real) .* 0.8
            ]
        end

        sl_red = IntervalSlider(
            rgbl.slidergrid[1,1], range=range(extrema(red_real)..., 500),
            startvalues=rgb_bounds[1]
        )
        red_label = Label(
            rgbl.slidergrid[2,1],
            @lift(
                string(
                    "Red Adjustment:",
                    round($(sl_red.interval)[1], digits=2), ", ",
                    round($(sl_red.interval)[2],digits=2)
                )
            ),
            tellwidth=false
        )

        sl_green = IntervalSlider(
            rgbl.slidergrid[3,1], range=range(extrema(green_real)...,500),
            startvalues=rgb_bounds[2]
        )

        green_label = Label(
            rgbl.slidergrid[4,1],
            @lift(
                string(
                    "Green Adjustment:",
                    round($(sl_green.interval)[1],digits=2), ", ",
                    round($(sl_green.interval)[2],digits=2)
                    )
            ),
            tellwidth=false
        )

        sl_blue = IntervalSlider(
            rgbl.slidergrid[5,1], range=range(extrema(blue_real)..., 500),
            startvalues=rgb_bounds[3]
        )

        blue_label = Label(
            rgbl.slidergrid[6,1],
            @lift(
                string(
                    "Blue Adjustment:",
                    round($(sl_blue.interval)[1],digits=2),", ",
                    round($(sl_blue.interval)[2],digits=2)
                )
            ),
            tellwidth=false
        )
        
        r = @lift(norm_im_controlled(arr[:,:,1],$(sl_red.interval)...))
        g = @lift(norm_im_controlled(arr[:,:,2],$(sl_green.interval)...))
        b = @lift(norm_im_controlled(arr[:,:,3],$(sl_blue.interval)...))

        rgb = @lift(RGBA.($r,$g,$b))

        sl_all = Slider(rgbl.slidergrid[7,1],range=0.1:0.01:4,startvalue=1)
        brightness_color = @lift(
            RGBA($(sl_all.value),$(sl_all.value),$(sl_all.value),1)
        )

        brightness_label = Label(
            rgbl.slidergrid[8,1],
            @lift(string("Brightness: ",$(sl_all.value))),
            tellwidth=false
        )

        rgb_multiply(x,y) = x ⊙ y

        rgb = @lift(mult_rgb.($rgb, $brightness_color))
        rgb[][isnan.(rgb[])] .= RGBA(0.0,0.0,0.0,0.0)
        on(rgb) do ob
            rgb[][isnan.(rgb[])] .= RGBA(0.0,0.0,0.0,0.0)
        end

        image!(image_axis,rgb,interpolate=false)
    end

    if typeof(h5loc) == H5raster
        adjust_parent_fig_cube(f)

        irl = ImageRasterLayout(parent_figure = f)

        imdata = ImageRasterData(arr[:,:,1], lbls, color_map)

        image_axis = get_image_axis(irl.imagegrid[1,1])
        image_axis.title = axis_title
    
        isl = color_range_selector(irl.slidergrid[1,1],imdata)
        activate_color_range_selector!(isl,imdata)
    
        hga = band_histogram(irl.histogramgrid,imdata)
        activate_band_histogram!(hga,imdata)
        
        if markbadvals
            image!(
                image_axis,
                imdata.display_matrix,
                colorrange=(-0.1,1.1),
                lowclip=:red,
                highclip=:red,
                interpolate=false,
                nan_color=:grey
        )
        else
            image!(
                image_axis,
                imdata.display_matrix,
                colorrange=imdata.color_range,
                interpolate=false,
                nan_color=:grey
        )
        end
    end

    display(GLMakie.Screen(focus_on_show=true),f)
    return f
end