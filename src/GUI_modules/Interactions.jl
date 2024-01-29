using GLMakie

function activate_spectral_grab(ax_spec,axes...)
    pllist = []
    pslist = []
    num_spectra = 0

    for (n,axis) in enumerate(axes)
        register_interaction!(axis,:Symbol("spectral_grab",n)) do event::MouseEvent,axis
            if event.type==MouseEventTypes.leftclick
                if num_spectra<9
                    num_spectra += 1
                else
                    num_spectra = 1
                end

                xpos = Int(round(event.data[1]))
                ypos = Int(round(event.data[2]))

                pl = lines!(ax_spec,λ_select,@lift($(spectra_select)[xpos,ypos,:]),color=num_spectra,colormap=:Set1_9,colorrange=(1,9),linestyle=:dash)

                ps = scatter!(axis,xpos,ypos,color=num_spectra,colormap=:Set1_9,colorrange=(1,9),markersize=5)

                push!(pllist,pl)
                push!(pslist,ps)
                println("X:$xpos, Y:$ypos")
            end
        end
    end
end