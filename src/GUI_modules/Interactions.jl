using GLMakie
using StatsBase
using PolygonOps

function activate_pointgrab!(plot_list::PlotsAccounting,im_mod::GUIModule,spec_mod::GUIModule,interaction_name::Symbol,linked_axes::Vector{Axis})

    register_interaction!(im_mod.axis,interaction_name) do event::MouseEvent,axis
        if event.type==MouseEventTypes.leftclick

            if plot_list.plot_number < 9
                plot_list.plot_number += 1
            else
                plot_list.plot_number = 1
            end

            xpos = Int(round(event.data[1]))
            ypos = Int(round(event.data[2]))

            pl = lines!(spec_mod.axis,@lift($(spec_mod.data).λ),@lift($(spec_mod.data).array[xpos,ypos,:]),color=plot_list.plot_number,colormap=:Set1_9,colorrange=(1,9),linestyle=:dash)

            ps = scatter!(im_mod.axis,xpos,ypos,color=plot_list.plot_number,colormap=:Set1_9,colorrange=(1,9),markersize=5)

            push!(plot_list.pointspec_plots,(spec_mod.axis,pl))
            push!(plot_list.image_scatters,(im_mod.axis,ps))

            for axis in linked_axes
                ps_link = scatter!(axis,xpos,ypos,color=plot_list.plot_number,colormap=:Set1_9,colorrange=(1,9),markersize=5)
                push!(plot_list.image_scatters,(axis,ps_link))
            end

            println("X:$xpos, Y:$ypos, $(plot_list.plot_number)")
        end
    end
end

function activate_areagrab!(plots_list::PlotsAccounting,im_mod::GUIModule,interaction_name::Symbol,linked_axes::Vector{Axis})

    register_interaction!(im_mod.axis,interaction_name) do event::KeysEvent, axis
        if all([i in event.keys for i in [Keyboard.q,Keyboard.left_shift]])
            mp = mouseposition(im_mod.axis)
            xpos = Int(round(mp[1]))
            ypos = Int(round(mp[2]))

            xsize = @lift(size($(im_mod.data).array,1))
            ysize = @lift(size($(im_mod.data).array,2))

            if 0<xpos<to_value(xsize) && 0<ypos<to_value(ysize)
                srfl = scatter!(im_mod.axis,xpos,ypos,color=:Red)
                push!(plots_list.area_scatters,(im_mod.axis,srfl))
    
                for ax in linked_axes
                    smap = scatter!(ax,xpos,ypos,color=:Red)
                    push!(plots_list.area_scatters,(im_mod.axis,smap))
                end
    
                push!(plots_list.area_coordinates,(xpos,ypos))
            end

        end
    end
end