struct ROI_stats
    spectra::Matrix{Float64} #NxM Matrix where N is the number of spectra and M is the number of bands
    specavg::Vector{Float64} #Average of all spectra
    specmin::Vector{Float64} #Minimum spectra
    specmax::Vector{Float64} #Maximum spectra
    specstd::Vector{Float64} #Standard Deviation spectra
end

function get_ROI_stats(roi_spectra :: Matrix{Float64}) #Dimensions are NxM where N is the number of spectra in ROI, M is the number of bands
    return ROI_stats(
        roi_spectra,
        vec(mean(roi_spectra,dims=1)),
        vec(minimum(roi_spectra,dims=1)),
        vec(maximum(roi_spectra,dims=1)),
        vec(std(roi_spectra,dims=1))
    )
end

@kwdef mutable struct ROI
    data_size::Tuple{Int64,Int64,Int64,Int64} = (0,0,0,0)
    collect_ROI::Observable{Bool} = Observable(false)
    coord_vec::Vector{GLMakie.Point{2,Int}} = Vector{GLMakie.GLMakie.Point{2,Int}}(undef,0)
    tracking_line::Vector{LineSegments{Tuple{Vector{GLMakie.Point{2, Float64}}}}} = Vector{LineSegments{Tuple{Vector{GLMakie.Point{2, Float64}}}}}(undef,0)
    nROI::Int = 1
    ROI_spectra::Array{Float64,3} = Array{Float64,3}(undef,0,data_size[3],data_size[4]) #NxMxK array where N is tje number of spectra within the ROI, M is the number of bands and K is the number of datasets plotted
    collection::Matrix{ROI_stats} = Matrix{ROI_stats}(undef,0,data_size[4]) #MxN matrix where M is the number of ROIs and N is the number of datasets being plotted
    roi_bitmask::Vector{Matrix{Bool}} = Vector{Matrix{Bool}}(undef,0) 
end

function Makie.process_interaction(interaction::ROI, event::MouseEvent, axis)
    if event.type === MouseEventTypes.leftclick && to_value(interaction.collect_ROI)
        pt = round.(Int,event.data)
        
        println("($(pt[1]),$(pt[2])) Added to ROI!")
        push!(interaction.coord_vec,pt)

        if length(interaction.tracking_line)>0
            ls_outline = linesegments!(axis,[pt,interaction.coord_vec[end-1]],color=interaction.nROI,colormap=:tab10,colorrange=(1,10))
        end
    end

    if event.type === MouseEventTypes.over && to_value(interaction.collect_ROI)

        pt = round.(Int,event.data)
        for i in interaction.tracking_line
            delete!(axis,i)
        end
        if length(interaction.coord_vec) > 0
            ls = linesegments!(axis,[pt,interaction.coord_vec[end]],color=interaction.nROI,colormap=:tab10,colorrange=(1,10))
            push!(interaction.tracking_line,ls)
        end

    end
end

function roi_visualizer(fig:: Figure, h5file:: String, name_vec:: Vector{String}, symb:: Symbol, wavelength_path::String; flip_image::Bool = false, linked_figures:: Vector{Figure}=Vector{Figure}(undef,0), same_axis::Bool = true,save_name::String="roi_save.hdf5")

    img_axis = fig.content[1]
    f = Figure()
    if same_axis
        spec_axis = Axis(f[1,1])
        b = Button(f[1,2],tellheight=false,label="Save Plot Data")
    else
        spec_axis_vec = [Axis(f[n,1]) for n in eachindex(name_vec)]
        b = [Button(f[n,2],tellheight=false,label="Save Plot Data") for n in eachindex(name_vec)]
    end

    println(fig.content)

    spec_data,wvl = h5open(h5file) do f
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

    myroi = ROI(data_size = size(spec_data))

    if same_axis
        on(b.clicks) do n
            sv = open_dialog_native("Select directory to save ROI spectra", action=GtkFileChooserAction.SELECT_FOLDER)
            h5open(joinpath(sv,save_name),"w") do f
                for j in eachindex(myroi.collection[1,:])
                    temp_arr = Array{Float64}(undef,size(myroi.collection,1),myroi.data_size[3])
                    println("Temp Array:",size(temp_arr))
                    
                    for i in eachindex(myroi.collection[:,1])
                        temp_arr[i,:] = myroi.collection[i,j].specavg
                    end

                    f[basename(name_vec[j])] = temp_arr
                end
            end 
        end
    end
    ax = axes(spec_data[:,:,:,1])
    function activate_roi_selector!(current_axis)
        on(events(current_axis).keyboardbutton) do event
            #Handling of r press
            if event.key == Keyboard.r && event.action == Keyboard.press
                myroi.collect_ROI[] = true
            elseif event.key == Keyboard.r && event.action == Keyboard.release
                myroi.collect_ROI[] = false
                if length(myroi.coord_vec)>0
                    linesegments!(current_axis,myroi.coord_vec[[1,end]],color=myroi.nROI,colormap=:tab10,colorrange=(1,10))
                    push!(myroi.coord_vec,myroi.coord_vec[1])
                end
            end

            #Handling of t press
            if event.key == Keyboard.t && event.action == Keyboard.press
                poly!(current_axis, myroi.coord_vec, color=myroi.nROI, colormap=:tab10,colorrange=(1,10), alpha=0.7)
                roi_px = map(CartesianIndices(ax[1:2])) do p
                    return inpolygon(p,myroi.coord_vec)
                end
                good_px = roi_px.==1 .&& isfinite.(spec_data[:,:,1,1])
                myroi.ROI_spectra = cat(myroi.ROI_spectra,spec_data[good_px,:,:],dims=1)
                myroi.coord_vec = Vector{GLMakie.Point{2,Int}}(undef,0)
                myroi.tracking_line = Vector{LineSegments{Tuple{Vector{GLMakie.Point{2, Float64}}}}}(undef,0)
            end
            
            #Handling of n press
            if event.key == Keyboard.n && event.action == Keyboard.press
                println(size(myroi.ROI_spectra))
                current_roi_stats = Vector{ROI_stats}(undef,0)
                for i in eachindex(myroi.ROI_spectra[1,1,:])
                    push!(current_roi_stats,get_ROI_stats(myroi.ROI_spectra[:,:,i]))
                end

                current_roi_stats = reshape(current_roi_stats,1,size(myroi.ROI_spectra,3))
                myroi.collection = cat(myroi.collection,current_roi_stats,dims=1)
                myroi.ROI_spectra = Array{Float64,3}(undef,0,myroi.data_size[3],myroi.data_size[4])
                myroi.nROI += 1
                println("ROI added to collection!")
                
            end

            #Handling of p press
            if event.key == Keyboard.p && event.action == Keyboard.press
                for i in eachindex(myroi.collection[:,1])
                    for j in eachindex(myroi.collection[1,:])
                        if same_axis
                            lines!(spec_axis,wvl,myroi.collection[i,j].specavg,color=i,colormap=:tab10,colorrange=(1,10))
                        else
                            lines!(spec_axis_vec[j],wvl,myroi.collection[i,j].specavg,color=i,colormap=:tab10,colorrange=(1,10))
                        end
                    end
                end
                display(GLMakie.Screen(),f)
            end
        end
    end

    activate_roi_selector!(img_axis)
    for figure in linked_figures
        linked_img_axis = figure.content[1]
        activate_roi_selector!(linked_img_axis)
    end

    try
        register_interaction!(img_axis, symb, myroi)
    catch
        deregister_interaction!(img_axis,symb)
        register_interaction!(img_axis, symb, myroi)
    end


    return nothing

end