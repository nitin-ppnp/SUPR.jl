# SUPR
Julia implementation of [SUPR](https://supr.is.tue.mpg.de) human body model.


## Download SUPR models
First, register on the SUPR website https://supr.is.tue.mpg.de/. Then download the Julia models or use the following script to download them.
```
. ./download_supr_model.sh
```

## Using the package
In julia REPL
```julia
]add https://github.com/nitin-ppnp/SUPR.jl
```

- run the following code to visualize the zero pose ($\theta$) and shape ($\beta$). Here we use 10 PCA coefficients for the shape, but it can be any number upto 400.
```julia
using SUPR;

# create SMPL model
supr = createSUPR("path/to/the/SMPL/model/.npz/file");

# get output dict containing the body vertices and 3D joints
supr_out = supr_lbs(supr,zeros(Float32,10),zeros(Float32,225));

# visualize zero pose and shape
viz_supr(supr,zeros(Float32,10),zeros(Float32,225),color=:turquoise)
```

## Explore first 10 shape components interactively
```julia
include("src/scripts/shape_interact.jl")
```