rangeof(x) = (tmp = extrema(x); return tmp[2] - tmp[1]) #Finds the statistical range of a dataset, x

"""
    ImageCubeData()

Stores pertinent data from an image cube representing spectral data

#Fields
-`im_array`: 3 dimensional array of all the image data
-`λ`: Vector of band wavelengths
-`selected_band`: Observable for the currently examined image band
-`color_map`: The current color map for the image to be displayed by
-`display_matrix`: matrix of the image that is currently displayed (i.e. one band of the `im_array`)
-`finite_data`: vector of all finite data in the currently displayed image (i.e. gets rid of NaN, inf, etc...)
-`histogram`: StatsBase.Histogram object for the finite data observable
-`color_range`: Tuple of th
"""
@kwdef mutable struct ImageCubeData
    im_array::Array{<:AbstractFloat}
    λ::Vector{<:AbstractFloat}
    selected_band::Observable{Int}
    color_map::Symbol
    display_matrix::Observable{Matrix{<:AbstractFloat}} = @lift(im_array[:,:,$selected_band])
    display_mask::Observable{BitMatrix} = @lift(isfinite.($display_matrix))
    finite_data::Observable{Vector{<:AbstractFloat}} = @lift($display_matrix[$display_mask])
    histogram::Observable{StatsBase.Histogram} = @lift(StatsBase.fit(Histogram,$finite_data,nbins=100))
    color_range::Observable{Tuple{<:AbstractFloat,<:AbstractFloat}} = @lift(extrema($finite_data))
end

@kwdef mutable struct ImageViewerLayout
    parent_figure::Figure
    imagegrid::GridLayout = parent_figure[1,1] = GridLayout()
    histogramgrid::GridLayout = parent_figure[2,1] = GridLayout()
    slidergrid::GridLayout = parent_figure[3,1] = GridLayout()
    buttongrid::GridLayout = parent_figure[4,1] = GridLayout()
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

function adjust_parent_fig(parent_figure::Figure) :: Nothing
    rowsize!(parent_figure.layout,1,Relative(5/7)) #Main Image Axis
    rowsize!(parent_figure.layout,2,Relative(1/10)) #Hsitogram Axis
end

function get_image_axis(parent_position::GridPosition)::Axis
    image_axis = Axis(parent_position,aspect=DataAspect())
    hidedecorations!(image_axis)
    hidespines!(image_axis)
    return image_axis
end

function color_range_selector(parent_position::GridPosition,imdata::ImageCubeData)::IntervalSlider
    r = @lift(range(extrema($(imdata.finite_data))...,100))
    isl = IntervalSlider(parent_position, range = r, tellwidth=true)
    return isl
end

function activate_color_range_selector!(isl::IntervalSlider,imdata::ImageCubeData)::Nothing
    imdata.color_range = isl.interval
    return nothing
end

function band_selector(parent_figure::Figure,parent_position::GridPosition,imdata::ImageCubeData) :: ButtonSelector
    println()
    b1 = parent_position[1,1] = Button(parent_figure,label="First Band")
    b2 = parent_position[1,2] = Button(parent_figure,label="Decrease Band")
    b3 = parent_position[1,3] = Button(parent_figure,label="Increase Band")
    b4 = parent_position[1,4] = Button(parent_figure,label="Last Band")
    parent_position[1,5] = Label(parent_figure,@lift(string("Band: ",$(imdata.selected_band))))
    parent_position[1,6] = Label(parent_figure,@lift(string("Wavelengths: ",round(imdata.λ[$(imdata.selected_band)],digits=2))))
    b7 = parent_position[1,7] = Textbox(parent_figure,placeholder="Jump to band...")

    return ButtonSelector(b1,b2,b3,b4,b7)
end

function activate_band_selector!(bs::ButtonSelector,imdata::ImageCubeData)::Nothing
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

function band_histogram(parent_position::GridLayout,imdata::ImageCubeData) :: Axis
    histogram_axis = Axis(parent_position[1,1])
    on(imdata.finite_data) do o
        reset_limits!(histogram_axis)
    end
    return histogram_axis
end

function activate_band_histogram!(hga::Axis,imdata::ImageCubeData) :: Nothing
    hist_colors = @lift([val > $(imdata.color_range)[1] && val < $(imdata.color_range)[2] ? :red : :transparent for val in $(imdata.histogram).edges[1]])
    hist!(hga,imdata.finite_data,bins=@lift(length($(hist_colors))),color=hist_colors,strokewidth=0.5,strokecolor=:black)
    return nothing
end

function band_colorbar(parent_position::GridLayout,imdata::ImageCubeData) :: Colorbar
    cbar = ColonBar(parent_position,limits=imdata.color_range,colormap=colormap)
end

"""
    image_visualizer()

#Arguments
-`h5loc::H5FileLocation`: H5FileLocation object to display as an image
-`band`: initial band of the data to display
-`color_map`: color map to display the data in
`flip_image`: Boolean for whether or not to flip the image on the y-axis. Often needed when reading from HDF5
"""
function image_visualizer(h5loc::T; band=nothing, color_map = :gray1, flip_image=false) where {T<:AbstractH5ImageLocation}
    arr,lbls = h52arr(h5loc)
    if flip_image arr = arr[:,end:-1:1,:]; println("test") end

    f = get_parent_fig()
    ivl = ImageViewerLayout(parent_figure = f)
    adjust_parent_fig(f)

    band = Observable(band)

    if typeof(h5loc) == H5cube
        if isnothing(band) println("Set the band!") end
        imdata = ImageCubeData(im_array = arr, λ=lbls, selected_band=band,color_map=color_map)
    end


    image_axis = get_image_axis(ivl.imagegrid[1,1])

    bs = band_selector(f,ivl.buttongrid[1,1],imdata)
    activate_band_selector!(bs,imdata)

    isl = color_range_selector(ivl.slidergrid[1,1],imdata)
    activate_color_range_selector!(isl,imdata)

    hga = band_histogram(ivl.histogramgrid,imdata)
    activate_band_histogram!(hga,imdata)


    image!(image_axis,imdata.display_matrix,colorrange=imdata.color_range)

    DataInspector(f)
    display(GLMakie.Screen(focus_on_show=true),f)

    return nothing
end