using GLMakie

f = Figure();ax = Axis(f[1,1])

l1 = lines!(ax,[0,1],[0,1],color=:black,linewidth=5)
l2 = lines!(ax,[1.5,2,4],[1,1,2],color=:black,linewidth=5)
l3 = lines!(ax,[2,3],[0,5],color=:black,linewidth=5)
s1 = scatter!(ax,4,4,color=:green)



function line_picker(ax::Axis)
    line_list = [i for i in ax.scene.plots if typeof(i) <: Lines]
    picked_state = Observable(BitVector(false*ones(length(line_list))))

    on(events(ax).mousebutton) do event
        if event.button == Mouse.left && event.action == Mouse.press
            plt,_ = pick(ax)
            if typeof(plt) <: Lines
                selected_idx = plt.==line_list
                selected_line = line_list[selected_idx][1]
                if !picked_state[][selected_idx][1]
                    picked_state[][selected_idx] .= true
                    selected_line.color[] = :red
                    notify(picked_state)
                else
                    picked_state[][selected_idx] .= false
                    selected_line.color[] = :black
                    notify(picked_state)
                end
            end
        end
    end
    return picked_state
end

picked_lines = line_picker(ax)
on(picked_lines) do ob
    println(ob)
end
f