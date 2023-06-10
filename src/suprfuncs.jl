using NPZ; npz=NPZ
using LinearAlgebra
using SparseArrays;
using SharedArrays;
using Makie;
using Distributed;
using TensorOperations;

struct SUPRdata
    v_template::Array{Float32,2}
    shapedirs::Array{Float32,3}
    posedirs::Array{Float32,3}
    J_regressor::SparseMatrixCSC{Float32, Int64}
    parents::Array{UInt32,1}
    lbs_weights::Array{Float32,2}
    f::Array{UInt32,2}
end

function createSUPR(model_path::String)
    """
    """
    model = NPZ.npzread(model_path);

    supr = SUPRdata(Float32.(model["v_template"]),
                    Float32.(model["shapedirs"]),
                    Float32.(model["posedirs"]),
                    sparse(Float32.(model["J_regressor"])),
                    UInt32.(model["kintree_table"][1,2:end].+1),
                    Float32.(model["weights"]),
                    model["f"].+1)        # python to julia indexing
    return supr
end

function quat_feat(theta)
    angle = norm(theta .+ 1f-8)
    normalized = theta ./ angle
    angle *= 0.5f0
    v_cos = cos(angle)
    v_sin = sin(angle)
    return vcat(v_sin * normalized, v_cos-1)
end

function rottrans2mat(rot, trans)
    return vcat(hcat(rot,trans),[0 0 0 1])
end

function so3_p_prod(rot, trans, point)
    return rot * point + trans
end

function so3_so3_prod(r1,t1,r2,t2)
    return r1*r2, r1*t2 + t1
end

function rodrigues(rot_vec,eps=1.0f-8)
    
    angle = sqrt(sum((rot_vec.+eps).^2))
    rot_dir = rot_vec ./ angle
    
    K = [0 -rot_dir[3] rot_dir[2] ;
        rot_dir[3] 0 -rot_dir[1] ;
        -rot_dir[2] rot_dir[1] 0]
    
    rot_mat = Matrix{Float32}(1.0I,3,3) + sin(angle)*K + (1-cos(angle))*K*K
    
    return rot_mat

end


function supr_lbs(supr,betas,pose=zeros(Float32,225),orient=zeros(Float32,3),trans=zeros(Float32,3))
    """
    """
    
    nbetas = length(betas);
    njoints = 75;
    nverts = 10475;

    pose = vcat(orient,pose)

    # v_shaped = reshape(reshape(supr.shapedirs,:,1:nbetas) * betas, size(supr.shapedirs,1),:) + supr.v_template;
    v_delta = zeros(Float32,nverts,3);
    @tensor v_delta[a,b] = supr.shapedirs[:,:,1:nbetas][a,b,c] * betas[c]
    v_shaped = supr.v_template + v_delta
    pad_v_shaped = [reshape(transpose(v_shaped),:);1];
    
    J = transpose(reshape(supr.J_regressor * pad_v_shaped,3,:));
    pose_quat = vcat([quat_feat(pose[3*(i-1)+1:3*i]) for i in axes(J,1)]...);
    
    R = vcat([reshape(rodrigues(pose[3*(i-1)+1:3*i]),1,3,3) for i in axes(J,1)]...);
    
    @tensor v_delta[a,b] = supr.posedirs[a,b,c]*pose_quat[c]
    v_posed = v_shaped + v_delta
    
    J_ = copy(J)
    J_[2:end,:] = J[2:end,:] - J[supr.parents,:]

    G = zeros(Float32,4,4,njoints);
    G[1:3,1:3,1] = R[1,:,:]
    G[1:3,4,1] = J_[1,:]
    for i = 2:75
        G[1:3,1:3,i], G[1:3,4,i] = so3_so3_prod(R[supr.parents[i-1],:,:],
                                                J_[supr.parents[i-1],:],
                                                R[i,:,:],
                                                J_[i,:])
        G[4,4,i] = 1f0
    end

    for i = 1:size(G,3)
        G[1:3,4,i] -= G[1:3,1:3,i] * J[i,:]
    end
    
    @tensor T[a,b,c] := G[b,c,d] * supr.lbs_weights[a,d]

    v = zeros(Float32,nverts,3)
    for i in 1:nverts
        v[i,:] = so3_p_prod(@view(T[i,1:3,1:3]),trans,v_posed[i,:])
    end
    
    root_transform = rottrans2mat(R[1,:,:],J[1,:])
    results = [root_transform]
    
    
    for i in eachindex(supr.parents)
        transform_i = rottrans2mat(R[i+1,:,:],J[i+1,:] - J[supr.parents[i],:])
        curr_res = results[supr.parents[i]] * transform_i
        append!(results,[curr_res])
    end
    
    posed_joints = zeros(Float32,size(results,1),3);
    for i in eachindex(results)
        posed_joints[i,:] = results[i][1:3,4] + trans
    end
    
    output = Dict("vertices" => v, 
                    "v_posed" => v_posed,
                    "v_shaped" => v_shaped,
                    "J_transformed" => posed_joints,
                    "f" => supr.f) 

    return output
end

function supr_lbs(supr::SUPRdata,betas::Array{Float32,2},pose::Array{Float32,1})
    output = Dict("vertices" => SharedArray{Float32}(size(betas,1),size(supr.v_template)...), 
                    "v_posed" => SharedArray{Float32}(size(betas,1),size(supr.v_template)...),
                    "v_shaped" => SharedArray{Float32}(size(betas,1),size(supr.v_template)...),
                    "J_transformed" => SharedArray{Float32}(size(betas,1),75,3),
                    "f" => supr.f) 
    
    Threads.@threads for i = 1:size(betas,1)
        out = supr_lbs(supr,betas[i,:],pose);
        output["vertices"][i,:,:] = out["vertices"]
        output["v_posed"][i,:,:] = out["v_posed"]
        output["v_shaped"][i,:,:] = out["v_shaped"]
        output["J_transformed"][i,:,:] = out["J_transformed"]
    end
    
    return output
end

function supr_lbs(supr::SUPRdata,betas::Array{Float32,1},pose::Array{Float32,2})
    output = Dict("vertices" => SharedArray{Float32}(size(betas,1),size(supr.v_template)...), 
                    "v_posed" => SharedArray{Float32}(size(betas,1),size(supr.v_template)...),
                    "v_shaped" => SharedArray{Float32}(size(betas,1),size(supr.v_template)...),
                    "J_transformed" => SharedArray{Float32}(size(betas,1),75,3),
                    "f" => supr.f) 
    
    Threads.@threads for i = 1:size(pose,1)
        out = supr_lbs(supr,betas,pose[i,:]);
        output["vertices"][i,:,:] = out["vertices"]
        output["v_posed"][i,:,:] = out["v_posed"]
        output["v_shaped"][i,:,:] = out["v_shaped"]
        output["J_transformed"][i,:,:] = out["J_transformed"]
    end
    
    return output
end



#############################################################################

function viz_supr(supr::SUPRdata,betas::Array{Float32,1},pose::Array{Float32,1};kwargs...)
    verts = supr_lbs(supr,betas,pose)["vertices"]
    scene = Makie.mesh(verts',supr.f;kwargs...)
    return scene
end