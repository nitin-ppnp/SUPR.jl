using Observables;
using SUPR;
using GLMakie;

Body_joint_names = ["Pelvis", 
"L_hip", 
"R_hip", 
"Lowerback", 
"L_knee", 
"R_knee", 
"Upperback", 
"L_ankle", 
"R_ankle", 
"Thorax", 
"L_foot", 
"R_foot",
"Neck",
"L_collar",
"R_collar",
"Head",
"L_shoulder",
"R_shoulder",
"L_elbow",
"R_elbow",
"L_wrist",
"R_wrist",
"L_hand",
"R_hand"
]

# supr = createSUPR(joinpath(@__DIR__,"../../models/SUPR_neutral.npz"));
supr = createSUPR(ARGS[1]);
njoints = parse(Int,ARGS[2]);

f = Figure()

scene = LScene(f[1,1],show_axis=false)
f[2, 1] = buttongrid = GridLayout(tellwidth = false)

njoints = 10

active_joint_id = 1
function get_active_joint_array(i)
    global njoints
    active_joint = zeros(Float32, njoints);
    active_joint[i] = 1
    return active_joint
end
# active_joint = @lift(get_active_joint_array($active_joint_id))

# buttonlabels = [@lift("J_$(i): $(active_joint[i])") for i in 1:njoints]
buttonlabels = [Body_joint_names[x+1] for x in 1:njoints]

buttons = buttongrid[1, 1:njoints] = [Button(f, label = l) for l in buttonlabels]


θ_1 = Slider(f[3,1], range = -1:0.01:1, startvalue = 0);
θ_2 = Slider(f[4,1], range = -1:0.01:1, startvalue = 0);
θ_3 = Slider(f[5,1], range = -1:0.01:1, startvalue = 0);

theta_init = zeros(Float32,225);
θ = Observable(zeros(Float32,225));

for i in 1:njoints
    on(buttons[i].clicks) do n
        global θ
        global theta_init = θ.val
        global active_joint_id = i
        set_close_to!(θ_1,theta_init[3*(i-1)+1])
        set_close_to!(θ_2,theta_init[3*(i-1)+2])
        set_close_to!(θ_3,theta_init[3*(i-1)+3])
    end
end

θ = @lift(vcat(theta_init[1:3*(active_joint_id-1)],[$(θ_1.value), $(θ_2.value), $(θ_3.value)],theta_init[3*(active_joint_id)+1:end]))

out = @lift(supr_lbs(supr,zeros(Float32,10),$θ)["vertices"]);

mesh!(scene,out,supr.f,color = :Turquoise)

cam = cameracontrols(scene)

rotate_cam!(scene.scene,cam,(-0.95, -2.365, 0))


display(f)

