using Statistics
using HDF5

"""
    movingavg(dataset::HDF5.File,box_size::Int)

TBW
"""
function movingavg(dataset::HDF5.File,box_size::Int)
    input_image = dataset["VectorDatasets/RawSpectra_GNDTRU"][:,:,:]
    input_λvector = read_attribute(dataset,"raw_wavelengths")

    if box_size%2==0
        throw(DomainError(box_size,"Box Size must be odd!"))
    end

    split_index::Int = (box_size-1)/2
    avg_im_size = (size(input_image)[1:2]...,size(input_image)[3]-(2*split_index))
    avg_im = zeros(avg_im_size)

    for band ∈ 1:size(avg_im)[3]
        subset_img = input_image[:,:,band:band+(2*split_index)]
        av_subset = mean(subset_img,dims=3)
        sd_subset = std(subset_img,dims=3)
        upperlim_subset = av_subset.+(2*sd_subset)
        lowerlim_subset = av_subset.-(2*sd_subset)

        
        subset_img[(subset_img.<lowerlim_subset).||(subset_img.>upperlim_subset)].=0.0
        wiseav_missingvals = convert(Array{Union{Float64,Missing}},subset_img)
        wiseav_missingvals[wiseav_missingvals.==0.0].=missing

        wiseav_denom = size(wiseav_missingvals)[3].-sum(ismissing.(wiseav_missingvals),dims=3)

        avg_im[:,:,band] = sum(subset_img,dims=3)./wiseav_denom
        avg_im = convert(Array{Float32},avg_im)
        #println("$(avg_im[20,20,band])...$band")
    end

    avg_λvector = input_λvector[split_index+1:size(input_image)[3]-split_index]

    try
        delete_object(dataset,"VectorDatasets/SmoothSpectra_GNDTRU")
    catch e
        println("Creating new smooth spectra dataset...")
    end
    
    dataset["VectorDatasets/SmoothSpectra_GNDTRU"] = avg_im

    try
        write_attribute(dataset,"smooth_wavelengths",avg_λvector)
    catch
        delete_attribute(dataset,"smooth_wavelengths")
        write_attribute(dataset,"smooth_wavelengths",avg_λvector)
    end

    return avg_im,avg_λvector
    println("Size of Image: $(size(input_image))")
end