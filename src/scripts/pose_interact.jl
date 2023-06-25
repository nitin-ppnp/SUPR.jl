using Observables;
using SUPR;
using GLMakie;

# supr = createSUPR(joinpath(@__DIR__,"../../models/SUPR_neutral.npz"));
# supr = createSUPR(ARGS[1]);
supr = createSUPR("models/SUPR_male.npz");

f = Figure()

scene = LScene(f[1,1],show_axis=false)
f[2, 1] = buttongrid = GridLayout(tellwidth = false)

njoints = 10

active_joint_id = Observable(1)
function get_active_joint_array(i)
    global njoints
    active_joint = zeros(Float32, njoints);
    active_joint[i] = 1
    return active_joint
end
active_joint = @lift(get_active_joint_array($active_joint_id))

# buttonlabels = [@lift("J_$(i): $(active_joint[i])") for i in 1:njoints]
buttonlabels = ["J_$x" for x in 1:njoints]

buttons = buttongrid[1, 1:njoints] = [Button(f, label = l) for l in buttonlabels]


θ_1 = Slider(f[3,1], range = -1:0.01:1, startvalue = 0);
θ_2 = Slider(f[4,1], range = -1:0.01:1, startvalue = 0);
θ_3 = Slider(f[5,1], range = -1:0.01:1, startvalue = 0);

for i in 1:njoints
    on(buttons[i].clicks) do n
        active_joint_id[] = i
    end
end


x = @lift(zeros(Float32,3*($active_joint_id-1)))
y = @lift(zeros(Float32,225-3*($active_joint_id)))
θ = @lift(vcat($x,[$(θ_1.value), $(θ_2.value), $(θ_3.value)],$y))
out = @lift(supr_lbs(supr,zeros(Float32,10),$θ)["vertices"]);

mesh!(scene,out,supr.f,color = :Turquoise)

cam = cameracontrols(scene)

rotate_cam!(scene.scene,cam,(-0.95, -2.365, 0))


display(f)

