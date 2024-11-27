using JENVI, GLMakie, HDF5

GLMakie.activate!()

myh5path = abspath("Data/targeted.hdf5")
h5 = h5open(myh5path)

mygui = JLGui(fig = Figure(backgroundcolor=:gray,
                     size=(1500,800)
                     ),
              data = h5
             )

config_vis_window!(mygui)
create_hdf5_tree!(mygui)
add_image_data!(mygui,mygui.A,"Vector")
add_image_data!(mygui,mygui.C,"Scalar")

# println(mygui.blocks)

GLMakie.activate!(title="JENVI Spatial Visualizer")
display(GLMakie.Screen(),mygui.fig)

# close(h5)