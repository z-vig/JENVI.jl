rangeof(x) = (tmp = extrema(x); return tmp[2] - tmp[1])

"""
    image_visualizer()

#Arguments
- `h5loc` 
"""
function image_visualizer(h5loc::HDF5FileLocation; band=nothing, band_names=nothing, colormap = :gray1, bands_first = false, flip_image=false, ax_name="",mark_badvals::Bool=false)
    arr,λ = h5open(h5loc.path) do f
        return read_dataset(f,h5loc.dat),attrs(f)[h5loc.wvl]
    end

    if bands_first
        asp = size(arr,2)/size(arr,3)
    else
        asp = size(arr,1)/size(arr,2)
    end

    f = Figure(size=(700,700))
    rowsize!(f.layout,1,Relative(5/7))
    igg = f[1,1] = GridLayout()
    ax = Axis(igg[2,1],aspect=asp)
    hidedecorations!(ax)
    hidespines!(ax)
    slg = f[3,1] = GridLayout()
    if ndims(arr) > 2

        if isnothing(band)
            println("Specify a band number!")
        end
        if bands_first
            nbands = size(arr,1)
        else
            nbands = size(arr,3)
        end
        f[4,1] = bgrid = GridLayout(tellwidth=false)
        band_obs = Observable(band)
        if !isnothing(band_names)
            Label(igg[1,1],@lift(band_names[$band_obs]*" "*ax_name),tellwidth=false)
        elseif isnothing(band_names)
            Label(igg[1,1],ax_name,tellwidth=false)
        end
        band_selector = bgrid[1,1:7] = [Button(f,label="First Band"),Button(f,label="Decrease Band"),Button(f,label="Increase Band"),Button(f,label="Last Band"),Label(f,@lift(string("Band: ",$band_obs))),Label(f,@lift(string("Wavelength: ",round(λ[$band_obs],digits=2)))),Textbox(f,placeholder="Jump to band...")]

        on(band_selector[1].clicks) do n
            band_obs[] = 1
        end

        on(band_selector[2].clicks) do n
            if to_value(band_obs) >= 2
                band_obs[] -= 1
                # println(to_value(band_obs))
            end
        end

        on(band_selector[3].clicks) do n
            if to_value(band_obs) <= nbands-1
                band_obs[] += 1
                # println(to_value(band_obs))
            end
        end

        on(band_selector[4].clicks) do n
            band_obs[] = nbands
        end

        on(band_selector[7].stored_string) do s
            band_obs[] = parse(Float64, s)
        end

        if bands_first
            img = @lift(arr[$(band_obs),:,:])
        else
            img = @lift(arr[:,:,$(band_obs)])
        end

        if flip_image
            img = @lift($img[:,end:-1:1])
        end

    else
        img = Observable(arr)
        if flip_image
            img[] = arr[:,end:-1:1]
        end
        Label(igg[1,1],ax_name,tellwidth=false)
    end

    img_finite = @lift($img[isfinite.($img)])

    # println(size(to_value(img_finite)))
    #Not sure if this working quite correctly yet...
    if to_value(@lift(iqr($img_finite)/rangeof($img_finite) < 0.01))
        println("Wonky Histogram Alert!")
        hist_data = @lift($img_finite[$img_finite.>percentile($img_finite,1) .&& $img_finite.<percentile($img_finite,98)])
    else
        hist_data = img_finite
    end
    on(img_finite) do x
        if to_value(@lift(iqr($img_finite)/rangeof($img_finite) < 0.01))
            println("Wonky Histogram Alert!")
            hist_data = @lift($img_finite[$img_finite.>percentile($img_finite,1) .&& $img_finite.<percentile($img_finite,98)])
        else
            hist_data = img_finite
        end
    end


    r = @lift(range(extrema($hist_data)...,100))
    # startvalues = @lift(tuple(nquantile($hist_data,10)[[2,10]]...))
    sl = IntervalSlider(slg[2,1],range = r, tellwidth=true)

    if !mark_badvals
        image!(ax,img,interpolate=false,colorrange=sl.interval,colormap=colormap)
    elseif mark_badvals
        image!(ax,img,interpolate=false,colorrange=(0,1),colormap=colormap,lowclip=:blue,highclip=:red)
    end
    Colorbar(igg[2,2],limits=sl.interval,colormap=colormap)

    h = @lift(StatsBase.fit(Histogram,$hist_data,nbins=100))
    hist_colors = @lift([val > $(sl.interval)[1] && val < $(sl.interval)[2] ? :red : :transparent for val in $h.edges[1]])

    histax = Axis(slg[1,1],aspect = 8,height=80,tellwidth=true)
    hist!(histax,hist_data,bins=@lift(length($(hist_colors))),color=hist_colors,strokewidth=0.5,strokecolor=:black)

    on(hist_data) do x
        # 
        reset_limits!(histax)
        r = to_value(@lift(tuple(nquantile($hist_data,10)[[2,10]]...)))
        r2 = extrema(to_value(sl.range))
        set_close_to!(sl,r2...)
    end

    # DataInspector(f)

    display(GLMakie.Screen(),f)

    return f
end

# plot_spec_data("C:/SelenoSpecData/M3_data/global/hdf5_files/global_175211.hdf5","ScalarDatasets/ParameterSuite1",band=3)