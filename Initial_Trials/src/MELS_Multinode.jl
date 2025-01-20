using JuMP
using Gurobi
using IterTools

###############################################################################
# 1. Define sets
###############################################################################
# Echelons (e=1 => factory echelon, e=2 => warehouse echelon)
E = 1:2

# Time periods (t=1,2,3)
Tset = 1:3

# Each echelon has multiple nodes:
N = Dict(
    1 => 1:2,  # echelon 1 has nodes n=1,2 (2 factories)
    2 => 1:2   # echelon 2 has nodes n=1,2 (2 distribution centers)
)

###############################################################################
# 2. Parameters
###############################################################################
# Demand: d[e, n, t] at each node (n) in each echelon (e), in each period (t).
combinations = [(e, n, t) for e in E for n in N[e] for t in Tset]
d = Dict(comb => 0.0 for comb in combinations)

# Example demands for demonstration:
# Echelon 1, Node 1
d[(1, 1, 1)] = 10.0
d[(1, 1, 2)] = 15.0
d[(1, 1, 3)] = 12.0
# Echelon 1, Node 2
d[(1, 2, 1)] = 0.0   # maybe this factory node has no direct external demand
d[(1, 2, 2)] = 0.0
d[(1, 2, 3)] = 0.0

# Echelon 2, Node 1
d[(2, 1, 1)] = 5.0
d[(2, 1, 2)] = 20.0
d[(2, 1, 3)] = 10.0
# Echelon 2, Node 2
d[(2, 2, 1)] = 0.0
d[(2, 2, 2)] = 0.0
d[(2, 2, 3)] = 20.0

# Production Costs c[e,n,t]

c = Dict(comb => 0.0 for comb in combinations)

# Echelon 1, node 1 costs
c[(1, 1, 1)] = 2.0
c[(1, 1, 2)] = 4.0
c[(1, 1, 3)] = 20.0
# Echelon 1, node 2 costs
c[(1, 2, 1)] = 3.0
c[(1, 2, 2)] = 5.0
c[(1, 2, 3)] = 10.0
# Echelon 2, node 1 costs
c[(2, 1, 1)] = 16.0
c[(2, 1, 2)] = 18.0
c[(2, 1, 3)] = 20.0
# Echelon 2, node 2 costs
c[(2, 2, 1)] = 18.0
c[(2, 2, 2)] = 19.0
c[(2, 2, 3)] = 25.0


# Holding Cost
combo_holding = [(e, n) for e in E for n in N[e]]
h = Dict(comb => 0.0 for comb in combo_holding)

h[(1, 1)] = 0.5
h[(1, 2)] = 0.7
h[(2, 1)] = 1.0
h[(2, 2)] = 1.2

#Production/Shipping Capacity
Cap = Dict(comb => 50.0 for comb in combinations)

# Shipping cost s[e, n, m, t]
combo_shipping = []  # Initialize an empty array to store the combinations

for e in E  # Iterate over echelons
    if e + 1 in keys(N)  # Check if the next echelon exists
        for n in N[e]  # Iterate over nodes in the current echelon
            for m in N[e+1]  # Iterate over nodes in the next echelon
                for t in Tset  # Iterate over time periods
                    push!(combo_shipping, (e, n, m, t))  # Add the combination to the array
                end
            end
        end
    end
end

s = Dict(comb => 0.0 for comb in combo_shipping)

# Example: fill in some values
for t in Tset
    s[(1, 1, 1, t)] = 0.2 + 0.1 * (t - 1)
    s[(1, 1, 2, t)] = 0.3 + 0.1 * (t - 1)
    s[(1, 2, 1, t)] = 0.25 + 0.05 * (t - 1)
    s[(1, 2, 2, t)] = 0.25 + 0.05 * (t - 1)
end


###############################################################################
# 3. Build Model
###############################################################################
model = Model(Gurobi.Optimizer)

@variable(model, x[e in E, n in N[e], t in Tset] >= 0)
@variable(model, I[e in E, n in N[e], t in 0:maximum(Tset)] >= 0)
@variable(model, f[e in E[1:end-1], n in N[e], m in N[e+1], t in Tset] >= 0)

@objective(model, Min,
    # Production + holding
    sum(c[(e, n, t)] * x[e, n, t] + h[(e, n)] * I[e, n, t]
        for e in E, n in N[e], t in Tset)
    +
    # Time-dependent shipping cost
    sum(s[(e, n, m, t)] * f[e, n, m, t]
        for e in E[1:end-1], n in N[e], m in N[e+1], t in Tset)
)

# (A) Initial/final inventory = 0
for e in E
    for n in N[e]
        @constraint(model, I[e, n, 0] == 0)
        @constraint(model, I[e, n, maximum(Tset)] == 0)
    end
end

# (B) Flow/inventory balance
for e in E
    for n in N[e]
        for t in Tset
            inbound = (e == 1) ? 0 : sum(f[e-1, j, n, t] for j in N[e-1])
            outbound = (e == maximum(E)) ? 0 : sum(f[e, n, m, t] for m in N[e+1])
            @constraint(model,
                I[e, n, t-1] + x[e, n, t] + inbound
                ==
                I[e, n, t] + outbound + d[(e, n, t)]
            )
        end
    end
end

###############################################################################
# 3. Build Model
###############################################################################
model = Model(Gurobi.Optimizer)

@variable(model, x[e in E, n in N[e], t in Tset] >= 0)
@variable(model, I[e in E, n in N[e], t in 0:maximum(Tset)] >= 0)
@variable(model, f[e in E[1:end-1], n in N[e], m in N[e+1], t in Tset] >= 0)

@objective(model, Min,
    # Production + holding
    sum(c[(e, n, t)] * x[e, n, t] + h[(e, n)] * I[e, n, t]
        for e in E, n in N[e], t in Tset)
    +
    # Time-dependent shipping cost
    sum(s[(e, n, m, t)] * f[e, n, m, t]
        for e in E[1:end-1], n in N[e], m in N[e+1], t in Tset)
)

# (A) Initial/final inventory = 0
for e in E
    for n in N[e]
        @constraint(model, I[e, n, 0] == 0)
        @constraint(model, I[e, n, maximum(Tset)] == 0)
    end
end

# (B) Flow/inventory balance
for e in E
    for n in N[e]
        for t in Tset
            inbound = (e == 1) ? 0 : sum(f[e-1, j, n, t] for j in N[e-1])
            outbound = (e == maximum(E)) ? 0 : sum(f[e, n, m, t] for m in N[e+1])
            @constraint(model,
                I[e, n, t-1] + x[e, n, t] + inbound
                ==
                I[e, n, t] + outbound + d[(e, n, t)]
            )
        end
    end
end

# (C) Production capacity
for e in E, n in N[e], t in Tset
    @constraint(model, x[e, n, t] <= Cap[(e, n, t)])
end

# (D) (Optional) shipping capacity
for e in E[1:end-1], n in N[e], m in N[e+1], t in Tset
    @constraint(model, f[e, n, m, t] <= 100.0)
end

optimize!(model)

###############################################################################
# 4. Print Results
###############################################################################
println("Optimal objective value = ", objective_value(model))

println("\nProduction Plan (x):")
for e in E, n in N[e], t in Tset
    println("x[$e,$n,$t] = ", value(x[e, n, t]))
end

println("\nInventory Plan (I):")
for e in E, n in N[e], t in 0:maximum(Tset)
    println("I[$e,$n,$t] = ", value(I[e, n, t]))
end

println("\nFlow Plan (f):")
for e in E[1:end-1], n in N[e], m in N[e+1], t in Tset
    println("f[$e,$n => $m, t=$t] = ", value(f[e, n, m, t]),
        ", cost=", s[(e, n, m, t)])
end