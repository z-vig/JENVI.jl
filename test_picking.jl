using GLMakie

f = Figure();ax = Axis(f[1,1])

l1 = lines!(ax,[0,1],[0,1],color=:black,linewidth=5)
l2 = lines!(ax,[1.5,2,4],[1,1,2],color=:black,linewidth=5)
l3 = lines!(ax,[2,3],[0,5],color=:black,linewidth=5)

line_list = [l1,l2,l3]

on(events(ax).mousebutton) do event
    if event.button == Mouse.left && event.action == Mouse.press
        plt, i = pick(ax)
        if typeof(plt) <: typeof(l1)
            selected_line = line_list[plt.==line_list]
            selected_line[1].color[] = :red
        end
        # selected_line.color = :black
        # line_select = zeros(length(line_list))
        # line_select[plt .== line_list] = 1
        # println(line_select)

    end

end



f