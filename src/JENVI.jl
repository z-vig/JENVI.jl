module JENVI

export ask_file,
       AbstractImageData,
       SpecData,
       MapData,
       GUIModule,
       PlotsAccounting,
       shadow_removal!,
       band_selector!,
       histogram_selector!,
       menu_selector!,
       clear_button!,
       plot_button!,
       activate_pointgrab!,
       activate_areagrab!

include("JenviGUI.jl")
using .JenviGUI

include("ImageData.jl")

include("GUI_modules/Interactions.jl")
include("GUI_modules/Observables.jl")

function display_h5file(h5path)
    h5file = h5open(h5path)
    println("\n---$(basename(h5path))---")
    for i in keys(h5file)
        println(i)
        for j in keys(h5file[i])
            println("  --> $j")
        end
    end
    close(h5file)
end

end