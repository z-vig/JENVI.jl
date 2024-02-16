#JenviGUI.jl
module JenviGUI
export ask_file

using GLMakie
using StatsBase
using PolygonOps
using Gtk4
using ColorBrewer

function ask_file(start_folder::String)
    path = open_dialog("Select Image to Visualize",parent(GtkWindow()),start_folder=start_folder)
    if isfile(path)
        return path
    else
        println("Please Select a file")
    end
end

end #JenviGUI