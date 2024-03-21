module JENVI

export ask_file,
       AbstractImageData,
       SpecData,
       MapData,
       ObservationData,
       LocationData,
       GUIModule,
       PlotsAccounting,
       shadow_removal!,
       band_selector!,
       histogram_selector!,
       menu_selector!,
       clear_button!,
       plot_button!,
       save_button!,
       print_button!,
       activate_pointgrab!,
       activate_areagrab!,
       activate_areaprint!,
       save_myfig,
       initialize_hdf5,
       combine_hdf5,
       apply_gnd_tru,
       movingavg,
       doubleLine_removal,
       facet_shadowmap,
       lowsignal_shadowmap,
       IBD_map,
       bandcenter_map,
       slope_map,
       display_h5file,
       findλ


include("JenviGUI.jl")
using .JenviGUI

include("ImageData.jl")

include("GUI_modules/Interactions.jl")
include("GUI_modules/Observables.jl")
include("GUI_modules/SaveConfig.jl")

include("PDSUtils.jl")

include("Preprocessing/GroundTruthCorrection.jl")
include("Preprocessing/SpectralSmoothing.jl")
include("Preprocessing/RemoveContinuum.jl")
include("Preprocessing/ShadowMap.jl")

include("SpectralParameters/IBD.jl")
include("SpectralParameters/BandCenter.jl")
include("SpectralParameters/TwoPointSlope.jl")

function display_h5file(h5file::HDF5.File)
    for i in keys(h5file)
        if typeof(h5file[i]) == HDF5.Group
            println("📁 $i")
            for j in keys(h5file[i])
                println("  📑 $j")
            end
        else typeof(h5file[i]) == HDF5.Dataset
            println("📑 $i")
        end
    end
end

function findλ(wvls::Vector{Float64},targetλ::Real)
    diff_vec = abs.(wvls.-targetλ)
    located_ind = findall(diff_vec.==minimum(diff_vec))
    actualλ = wvls[located_ind]
    return located_ind[1],actualλ[1]
end

end