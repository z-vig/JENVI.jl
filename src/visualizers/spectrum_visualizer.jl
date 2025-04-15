"""
Controls:
Enter Visualize Spectra Mode (m)
Exit Visualize Spectra Mode (l)
Get Spectrum (left click)
Collect Spectrum (double left click)
Average Current Collection (a)
"""

const SPECTRAL_ASPECT_RATIO = 5/4
const SPECTRAL_LINE_WIDTH = 3

SPECTRAL_PLOT_COLORMAP = distinguishable_colors(
    15, [RGB(1,0,0), RGB(0,1,0), RGB(0,0,1)], dropseed=false
)

GLMakie.activate!()

function get_parent_fig_sv()::Figure
    m1 = GLFW.GetPrimaryMonitor()
    vm = GLFW.GetVideoMode(m1)
    f = Figure(
        fonts=(; regular="Verdana", bold="Verdana Bold"),
        size=(vm.width/2,vm.height/2)
    )
    return f
end

function adjust_parent_fig_sv(
    parent_figure::Figure,
    svl::SpectralViewerLayout
)::Nothing
    rowsize!(parent_figure.layout,1,Relative(7/8))
    colsize!(parent_figure.layout,2,Relative(1/8))
    # colsize!(svl.spectrumgrid,3,Relative(1/9))
    # colsize!(svl.spectrumgrid,4,Relative(1/9))
    return nothing
end

function get_spectrum_axis(
    parent_position::GridPosition,
    λ::Vector{<:AbstractFloat}
) :: Axis
    spectrum_axis = Axis(parent_position,aspect=SPECTRAL_ASPECT_RATIO)
    format_regular!(spectrum_axis)
    xlims!(extrema(λ)...)
    ylims!(0,0.5)
    return spectrum_axis
end

function activate_tracking_lines!(
    ss::SpectraSearch,
    image_axis::Axis
) :: Nothing
    on(ss.active) do ob
        if ob
            @debug "Current Limits: " current_limits
            v = vlines!(
                image_axis, 
                @lift($(ss.cursor_tracker)[1]), 1,
                ss.cube_size[2], color=:red
            )
            h = hlines!(
                image_axis,
                @lift($(ss.cursor_tracker)[2]), 1,
                ss.cube_size[1], color=:red
            )
            push!(ss.tracker_lines,v)
            push!(ss.tracker_lines,h)
            @debug "Tracker lines stored: " length(ss.tracker_lines)
        elseif !ob
            for i in ss.tracker_lines delete!(image_axis,i) end
        end
    end
    return nothing
end

function plot_spectrum_data!(
    imax::Axis,
    specax::Axis,
    sd::SpectrumData
)::Nothing
    lines!(
        specax,
        sd.λ, sd.data,
        color=sd.color, label=sd.name,
        linewidth=SPECTRAL_LINE_WIDTH, linestyle=:solid
    )
    scatter!(
        imax,
        sd.xpixel, sd.ypixel,
        color=sd.color, strokecolor=:black, strokewidth=2
    )
    return nothing
end

function activate_spectral_operations!(
    parent_figure::Figure,
    parent_position::GridLayout,
    collect_axis::Axis,
    sc::SpectraCollection
) :: Axis
    tog1_grid = parent_position[1,1] = GridLayout()
    tog1 = Toggle(tog1_grid[1,1],tellwidth=false)
    kernelsize_slider = Slider(
        tog1_grid[2,1:2],
        tellwidth=false,
        tellheight=false,
        range=3:2:41,
        startvalue=9
    )

    Label(
        tog1_grid[1,2],
        @lift(string("Kernel Size: ",$(kernelsize_slider.value))),
        tellwidth=false
    )

    b2 = parent_position[1,2] = Button(parent_figure,label="Remove Continuum")
    # colsize!(parent_position,3,100)
    # l1 = Label(tog_gp[1,1],"New Plot?",tellheight=false,tellwidth=false)
    # t1 = Toggle(tog_gp[1,2],tellheight=false,tellwidth=false)

    smoothed_data = Vector{Observable}(undef,0)
    smoothed_data_λ = Vector{Observable}(undef,0)
    on(tog1.active) do butt
        if butt

            empty!(collect_axis)
            for i in sc.spectra

                lines!(
                    collect_axis,
                    i.λ, i.data[],
                    color=i.color,linestyle=:dash,alpha=0.4,label=i.name
                )

                # First index is smoothed data, second is standard deviation,
                # third is valid indices
                mavg_res = @lift(
                    moving_avg(
                        i.data[],
                        box_size = $(kernelsize_slider.value),
                        edge_handling="extrapolate",
                        rm_outliers=true
                    )
                )
                plotx = Observable(Vector{Float32}(undef,0))
                ploty = Observable(Vector{Float32}(undef,0))
                on(mavg_res) do ob
                    plotx.val = i.λ[mavg_res[][3]]
                    ploty[] = mavg_res[][1]
                end
                lines!(
                    collect_axis,
                    plotx, ploty,
                    color=i.color, linestyle=:solid,
                    alpha=1.0, label=string(i.name,"_smooth")
                )
                notify(mavg_res)
                push!(smoothed_data,ploty)
                push!(smoothed_data_λ,plotx)
            end
        elseif !butt
            empty!(collect_axis)
            smoothed_data = Vector{Observable}(undef,0)
            smoothed_data_λ = Vector{Observable}(undef,0)
            for i in sc.spectra
                lines!(
                    collect_axis,
                    i.λ, i.data[],
                    color=i.color, linestyle=:solid,
                    alpha=1.0, label=i.name
                )
            end
        end
    end

    f_contrem = Figure(
        fonts = (; regular="Verdana",bold="Verdana Bold"));
        ax_contrem = Axis(f_contrem[1,1]
    )
    on(b2.clicks) do butt
        empty!(ax_contrem)
        format_continuum_removed!(ax_contrem)
        xlims!(extrema(sc.spectra[1].λ)...)
        for (i,j,k) in zip(sc.spectra,smoothed_data,smoothed_data_λ)
            contrem_λ = Observable(Vector{Float32}(undef,0))
            contrem_y = Observable(Vector{Float32}(undef,0))
            on(j) do ob
                contrem_y.val = ob
                contrem_λ[] = k[].*1000
                autolimits!(ax_contrem)
            end
            notify(j)

            #First index is the continuum line,
            #Second index is the continuum removed spectrum
            dlr_result = @lift(double_line_removal($contrem_λ,$contrem_y)) 
            lines!(
                collect_axis,
                k, @lift($dlr_result[1]),
                color=i.color, alpha=0.8,
                linestyle=:solid, label=string(i.name,"_continuum")
            )
            lines!(
                ax_contrem,
                k, @lift($dlr_result[2]),
                color=i.color, linewidth=SPECTRAL_LINE_WIDTH,
                linestyle=:solid, label=string(i.name,"_contrem")
            )
        end
        display(GLMakie.Screen(),f_contrem)
    end
    return ax_contrem
end

function activate_save_buttons!(
    parent_figure::Figure,
    parent_position::GridLayout,
    collect_axis::Axis,
    contrem_axis::Axis,
    image_axis::Axis,
    sc::SpectraCollection
)::Nothing
    b1 = parent_position[1,1] = Button(parent_figure,label="Save Collection")
    b2 = parent_position[1,2] = Button(parent_figure,label="Save Continuum Removal")
    b3 = parent_position[1,3] = Button(parent_figure,label="Save Image")
    txt = Textbox(
        parent_position[1,4],
        placeholder="Enter Save Name...",
        tellheight=false,
        tellwidth=false
    )
    
    savename = txt.stored_string

    on(b1.clicks) do butt
        filepath = open_dialog_native(
            "Select Directory to Save Spectra",
            action=GtkFileChooserAction.SELECT_FOLDER
        )
        export_spectra(collect_axis,filepath,savename=savename[],sc)
    end

    on(b2.clicks) do butt
        filepath = open_dialog_native(
            "Select Directory to Save Spectra",
            action=GtkFileChooserAction.SELECT_FOLDER
        )
        export_spectra(contrem_axis,filepath,savename=savename[],sc)
    end

    on(b3.clicks) do butt
        filepath = open_dialog_native(
            "Select Directory to Save Spectra",
            action=GtkFileChooserAction.SELECT_FOLDER
        )
        export_image(image_axis,filepath,savename=savename[])
    end
    return nothing
end

function custom_name_box(parent_position::GridPosition)::Observable
    txt = Textbox(
        parent_position[1,1],
        placeholder="Enter Spectrum Name...",
        tellheight=false, tellwidth=false
    )
    return txt.stored_string
end

function activate_toggles!(
    parent_position::GridPosition, sc::SpectraCollection
)::Nothing
    t1_grid = parent_position[1,1]
    t1_label = Label(
        t1_grid[1,1],"Set Custom\n Spectrum Name?",tellheight=false
    )
    t1_toggle = Toggle(t1_grid[1,2],tellheight=false,tellwidth=false)
    sc.custom_name = t1_toggle.active
    return nothing
end

function Makie.process_interaction(
    interaction::Union{SpectraSearch,SpectraCollection}, 
    event::KeysEvent,
    axis
)

    #Activates spectral selection
    if Makie.Keyboard.m in event.keys
        interaction.active[] = true
    elseif Makie.Keyboard.l in event.keys
        interaction.active[] = false
    end

    #Activates spectral averaging
    if Makie.Keyboard.a in event.keys && interaction.active[]
        interaction.averaging[] = true
    elseif Makie.Keyboard.s in event.keys && interaction.active[]
        interaction.averaging[] = false
    end

    if (Makie.Keyboard.right in event.keys) &&
       (typeof(interaction) == SpectraCollection)
        
       interaction.collect_number[] += 1
    end

    @debug "Search Spectra state: " interaction.active typeof(interaction)
end

function Makie.process_interaction(
    interaction::SpectraSearch, event::MouseEvent, axis
)
    if to_value(interaction.active)
        if event.type === MouseEventTypes.over
            interaction.cursor_tracker[] = event.data
        end
        if event.type == MouseEventTypes.leftclick
            pt = round.(Int,event.data)
            interaction.selected_tracker[] = pt

            @info "Plotted Spectrum at ("
                  "$(to_value(interaction.selected_tracker)[1]), "
                  "$(to_value(interaction.selected_tracker)[2]))"
        end
    end
end

"""
    spectrum_visualizer(
        connected_image::Figure, 
        h5loc::T;
        flip_image::Bool = false
    ) :: Nothing where {T<:AbstractH5ImageLocation}

Attaches a spectral visualizer window to an existing image visualizer window.

# Arguments
- `connected_image::Figure`: The figure object from the connected image visualizer
- `h5loc::T`: AbstractH5FileLocation of the spectral data
- `flip_image::Bool`: Boolean to flip the image along the y-axis
"""
function spectrum_visualizer(
    connected_image::Figure,
    h5loc::T;
    flip_image::Bool = false
) :: Nothing where {T<:AbstractH5ImageLocation}

    #Loads in data from h5loc file
    arr,λ = h52arr(h5loc)
    λ = λ./1000
    #Flips the image along the y-axis
    if flip_image arr = arr[:,end:-1:1,:]
        @debug "spectrum_visualizer has flipped the image." end

    #Gets image axis object from the connected_image figure
    image_axis = connected_image.content[1]

    #sets up the spectrum axis
    f = get_parent_fig_sv()
    svl = SpectralViewerLayout(parent_figure = f)
    spectrum_axis = get_spectrum_axis(svl.spectrumgrid[1,1],λ)
    collection_axis = get_spectrum_axis(svl.spectrumgrid[1,2],λ)

    #Initializing state objects for collecting and searching for spectra
    ss = SpectraSearch(cube_size = arr.size)
    sc = SpectraCollection(cube_size = arr.size)

    collection_legend = Legend(svl.legendgrid[1,1],[],[])

    #Activates horizontal and vertical lines that appear in collection mode
    activate_tracking_lines!(ss,image_axis)

    #Registering clicks and keyboard presses
    register_interaction!(image_axis,:specsearch,ss)
    register_interaction!(image_axis,:speccollect,sc)

    bg1 = svl.buttongrid[1,1] = GridLayout()
    bg2 = svl.buttongrid[1,2] = GridLayout()
    contrem_axis = activate_spectral_operations!(f,bg2,collection_axis,sc)
    activate_save_buttons!(f,bg1,collection_axis,contrem_axis,image_axis,sc)
    # activate_toggles!(svl.spectrumgrid[1,4],sc)
    current_name = custom_name_box(svl.legendgrid[2,1])

    #Observable function for plotting a single spectrum
    on(ss.selected_tracker) do ob
        if !isempty(ss.current_spectrum)
            for i in ss.current_plot delete!(spectrum_axis,i) end
        end
        current_spec = arr[ob[1],ob[2],:]
        l = lines!(
            spectrum_axis,
            λ, current_spec,
            color=:black, linewidth=SPECTRAL_LINE_WIDTH
        )
        autolimits!(spectrum_axis)
        ss.current_spectrum = current_spec
        push!(ss.current_plot,l)
        @debug "Plotting Spectrum" ob
    end

    #Observable function for adding a spectrum to the spectra collection
    on(sc.collect_number) do ob
        @debug "Custom Name Boolean:" sc.custom_name
        if !isnothing(current_name[])
            name = current_name[]
        else
            name = "spectrum$(to_value(ob))"
        end

        if !sc.averaging[]
            current_specdata = SpectrumData(
                λ,Observable(ss.current_spectrum),
                name,
                SPECTRAL_PLOT_COLORMAP[to_value(ob)],
                ss.current_plot[1],
                to_value(ss.selected_tracker)...,
                LineElement(
                    color=SPECTRAL_PLOT_COLORMAP[to_value(ob)],
                    label=name
                )
            )

            push!(sc.spectra,current_specdata)

            plot_spectrum_data!(image_axis,collection_axis,current_specdata)
            autolimits!(collection_axis)

            leg_entry = LegendEntry(
                [current_specdata.legend_entry],
                current_specdata.legend_entry.attributes
            )
            push!(collection_legend.entrygroups[][1][2],leg_entry)
            notify(collection_legend.entrygroups)
            @debug "SpectraCollection length: " length(sc.spectra)

        elseif sc.averaging[]
            sc.collect_number.val -= 1
            ob-=1

            partofmean = SpectrumData(
                λ,Observable(ss.current_spectrum),
                name,
                SPECTRAL_PLOT_COLORMAP[to_value(ob)],
                ss.current_plot[1],
                to_value(ss.selected_tracker)...,
                LineElement(color=SPECTRAL_PLOT_COLORMAP[to_value(ob)],label=name)
                )
            push!(sc.temp_mean_collection[],partofmean)
            notify(sc.temp_mean_collection)

            scatter!(
                image_axis,
                partofmean.xpixel, partofmean.ypixel,
                color=partofmean.color, strokewidth=2, strokecolor=:black
            )

            @info "($(partofmean.xpixel),$(partofmean.ypixel)) "
                  "added to current mean ($(length(sc.temp_mean_collection[]))"
                  "spectra.)"
        end
    end

    #Observable function to handle spectral averaging
    on(ss.averaging) do ob
        #Sets averaging indicator as a red border around the collection axis
        if ob && !isempty(sc.spectra)
            if isempty(sc.temp_mean_collection[])
                delete!(collection_axis,collection_axis.scene.plots[end])

                startofmean = sc.spectra[end] #Starting the mean Vector
                push!(sc.temp_mean_collection[],startofmean)
                mean_spectrum = MeanSpectrum(
                    λ,
                    @lift([i.data[] for i in $(sc.temp_mean_collection)]),
                    startofmean.name,
                    startofmean.color,
                    @lift([i.xpixel for i in $(sc.temp_mean_collection)]),
                    @lift([i.ypixel for i in $(sc.temp_mean_collection)]),
                    startofmean.legend_entry
                )

                mean_data = @lift(mean($(mean_spectrum.data)))

                p = lines!(
                    collection_axis,
                    mean_spectrum.λ, mean_data,
                    color=mean_spectrum.color, label=mean_spectrum.name
                )

                collection_axis.rightspinecolor = :red
                collection_axis.leftspinecolor = :red
                collection_axis.topspinecolor = :red
                collection_axis.bottomspinecolor = :red
                pop!(sc.spectra)
                push!(sc.spectra,SpectrumData(
                    mean_spectrum.λ,
                    mean_data,
                    mean_spectrum.name,
                    mean_spectrum.color,
                    p,
                    mean(mean_spectrum.xpixels[]),
                    mean(mean_spectrum.ypixels[]),
                    mean_spectrum.legend_entry
                ))
            else
                @warn "End the current mean collection first (press s)!"
            end


        elseif !ob && !isempty(sc.spectra)
            collection_axis.rightspinecolor = :black
            collection_axis.leftspinecolor = :black
            collection_axis.topspinecolor = :black
            collection_axis.bottomspinecolor = :black
            sc.temp_mean_collection = Observable(Vector{SpectrumData}(undef,0))
        else
            println("Put at least one spectrum in your collection!")
        end
    end

    adjust_parent_fig_sv(f,svl)
    display(GLMakie.Screen(),f)
    return nothing
end