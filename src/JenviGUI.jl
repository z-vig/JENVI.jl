#JenviGUI.jl
module JenviGUI
export JLGui,
       config_vis_window!,
       create_hdf5_tree!,
       add_image_data!

using GLMakie
using StatsBase
using PolygonOps
using ColorBrewer
using HDF5

Base.@kwdef mutable struct JLGui
    fig :: Figure
    data :: HDF5.File
    current_vectordata :: Observable{Array{<:AbstractFloat,3}} = Observable(Array{Float32}(undef,0,0,1))
    current_scalardata :: Observable{Array{<:AbstractFloat,2}} = Observable(Array{Float32}(undef,0,0))
    LEFT :: GridLayout = fig[1,1] = GridLayout()
    RIGHT :: GridLayout = fig[1,2] = GridLayout()
    A :: GridLayout = LEFT[1,1] = GridLayout()
    B :: GridLayout = LEFT[2,1] = GridLayout()
    C :: GridLayout = RIGHT[1,1] = GridLayout()
    D :: GridLayout = RIGHT[2,1] = GridLayout()
    blocks :: Dict = Dict()
end

function close_gui!(gui::JLGui)
    close(gui.data)
end

function config_vis_window!(gui::JLGui)
    ##Setting up the settings panel below the images
    rowsize!(gui.LEFT,2,Relative(1/4))
    rowsize!(gui.RIGHT,2,Relative(1/4))
end

function create_hdf5_tree!(gui::JLGui)
    """
    Function to read in an HDF5 file of a specific format related to Hyperspectral Analysis. The file must include the following groups of data:
        1. Backplanes // Any pixel-by-pixel metadata such as lat/long or observation geometry
        2. ShadowMaps // Maps showing which pixels to exclude from analysis (e.g. shadowed pixels)
        3. VectorDatasets // All datasets that have 3 dimensions, with the first being the spectral dimension (e.g. Array(undef,(281,2000,2000)) )
        4. ScalarDatasets // All datsets that have 2 dimensions. (e.g. Array(undef,(2000,2000)))

    The HDF5 file must also contain the channel labels (i.e. wavelengths) as attributes. These can be the raw channel labels as well as any derived channel labels (such as channel labels after smoothing)

    Blocks added to GUI:
        vec_menu // Menu object corresponding to vector data
        sca_menu // Menu object corresponding to scalar data
    """

    left_menu_row = gui.B[1,1] = GridLayout()
    colsize!(left_menu_row,1,Relative(1/4))

    right_menu_row = gui.D[1,1] = GridLayout()
    colsize!(right_menu_row,1,Relative(1/4))

    Label(left_menu_row[1,1],
          "Vector Data:",
          tellheight=false,tellwidth=false
          )

    vec_menu = Menu(left_menu_row[1,2],
                    options=zip(keys(gui.data["VectorDatasets"]),
                     [gui.data["VectorDatasets/$i"] for i in keys(gui.data["VectorDatasets"])]),
                    default = keys(gui.data["VectorDatasets"])[1],
                    tellheight=false,tellwidth=false
         )

    Label(right_menu_row[1,1],
          "Scalar Data:",
          tellheight=false,tellwidth=false
          )

    sca_menu = Menu(right_menu_row[1,2],
                    options=zip(keys(gui.data["ScalarDatasets"]),
                                [gui.data["ScalarDatasets/$i"] for i in keys(gui.data["ScalarDatasets"])]),
                    default = keys(gui.data["ScalarDatasets"])[1],
                    tellheight=false,tellwidth=false
         )

    gui.blocks["vec_menu"] = vec_menu
    gui.blocks["sca_menu"] = sca_menu
end

function add_image_data!(gui::JLGui,pos::GridLayout,type::String)
    """
    Function to add image data to plot based on selection from hdf5 tree.

    Blocks added to GUI
        $(type)_imaxis // Axis object for specified image type (i.e. vector or scalar)
        $(type)_histaxis // Axis object for histogram of the corresponding image
        channel_selector // Slider object for selecting the channel displayed for vector data
        hist_slider // Slider object for narrowing down the histogram
    """

    im_layout = pos[1,2] = GridLayout()
    A_image = Axis(im_layout[1,1],aspect = AxisAspect(1))
    A_hist = Axis(im_layout[2,1])

    rowsize!(im_layout,2,Relative(1/6))
    rowgap!(im_layout,5)
    colsize!(pos,1,Relative(1/16))
    colgap!(pos,2)

    hidedecorations!(A_image)
    hideydecorations!(A_hist)

    gui.blocks["$(type)_imaxis"] = A_image
    gui.blocks["$(type)_histaxis"] = A_hist

    #Plotting the actual data connected to the respective menu
    if type=="Vector"
        gui.current_vectordata = @lift(read($(gui.blocks["vec_menu"].selection)))

        channel_selector = Slider(pos[1,1],
        range = @lift(range(1,size($(gui.current_vectordata))[end])),
        startvalue = 1,
        horizontal=false,
        tellwidth=false,tellheight=false
        )

        gui.blocks["channel_selector"] = channel_selector

        hist_slider = IntervalSlider(pos[2,2],
        range=@lift(range(minimum($(gui.current_vectordata)),
                          maximum($(gui.current_vectordata)),
                          length=1000
                         )
                    )
        )
    
        gui.blocks["$(type)_histslider"] = hist_slider

        image!(gui.blocks["$(type)_imaxis"],
               @lift($(gui.current_vectordata)[:,:,$(gui.blocks["channel_selector"].value)]),
               colorrange=gui.blocks["$(type)_histslider"].interval
               )

        histobs = lift(gui.current_vectordata,gui.blocks["channel_selector"].value) do obs,chann
            obs[:,:,chann][isfinite.(obs[:,:,chann])]
        end

        hist!(gui.blocks["$(type)_histaxis"],
              histobs
              )
        vlines!(gui.blocks["$(type)_histaxis"],
              @lift([extrema($(gui.blocks["$(type)_histslider"].interval))...])
              )
        
        on(channel_selector.value) do val
            xlims!(gui.blocks["$(type)_histaxis"],extrema(histobs.val)...)
        end

        on(gui.blocks["vec_menu"].selection) do sel
            xlims!(gui.blocks["$(type)_histaxis"],extrema(histobs.val)...)
            gui.current_vectordata = read(sel)
        end

    elseif type == "Scalar"
        gui.current_scalardata = @lift(read($(gui.blocks["sca_menu"].selection)))

        hist_slider = IntervalSlider(pos[2,2],
        range=@lift(range(minimum($(gui.current_scalardata)),
                          maximum($(gui.current_scalardata)),
                          length=1000
                         )
                    )
        )
    
        gui.blocks["$(type)_histslider"] = hist_slider

        image!(gui.blocks["$(type)_imaxis"],
               gui.current_scalardata,
               colorrange=gui.blocks["$(type)_histslider"].interval)

        histobs = lift(gui.current_scalardata) do obs
            vec(obs[isfinite.(obs)])
        end

        hist!(gui.blocks["$(type)_histaxis"],
              histobs,
              bins=100
              )
        vlines!(gui.blocks["$(type)_histaxis"],
                @lift([extrema($(gui.blocks["$(type)_histslider"].interval))...])
                )

        on(gui.blocks["sca_menu"].selection) do sel
            reset_limits!(gui.blocks["$(type)_histaxis"],xauto=false,yauto=true)
            xlims!(gui.blocks["$(type)_histaxis"],extrema(histobs.val)...)
            gui.current_scalardata = read(sel)

        end
    end

    #Connecting the histogram to the plot

end


end #JenviGUI