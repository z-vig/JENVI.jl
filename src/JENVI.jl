module JENVI

export ask_file,
       build_gui,
       reflectanceviewer,
       mapviewer,
       histogramviewer,
       spectralviewer,
       init_fig,
       init_obs,
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


end