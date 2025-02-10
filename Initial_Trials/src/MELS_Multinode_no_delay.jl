using JuMP
using Gurobi
using MathOptInterface
const MOI = MathOptInterface
using Plots


###############################################################################
# 1. Define sets
###############################################################################
# Echelons
E_max = 4
E = 1:E_max

# Time periods (t=1,2,3)
Tset = 1:6

# K manufacturing nodes
K = 3 # the first 3 echelons do manufacturing

# Each echelon has multiple nodes:
N = Dict(
    1 => 1:5,  # echelon 1 has nodes 1,2
    2 => 1:4,  # echelon 2 has nodes 1,2
    3 => 1:2,  # echelon 3 has node 1
    4 => 1:2   # echelon 4 has node 1
)


# Dictionary to store incoming connections (from echelon e-1 to echelon e)
incoming_connections = Dict{Tuple{Int,Int},Vector{Int}}()

# Initialize dictionary for all nodes in echelons 2 to max(E)
for e in eachindex(N)  # `eachindex(N)` provides safe iteration
    for node in N[e]
        incoming_connections[(e, node)] = Int[]  # Start with an empty list
    end
end

# Connections

#echelon 2
push!(incoming_connections[(2, 1)], 1)  # limestone -> crushed limestone

for node in N[1]  # clinker production
    push!(incoming_connections[(2, 2)], node)
end

#echelon 3
push!(incoming_connections[(3, 1)], 1) # crushed limestone ->OPC
push!(incoming_connections[(3, 1)], 2) # CLINKER -> OPC
push!(incoming_connections[(3, 1)], 3) # Gypsum -> OPC

push!(incoming_connections[(3, 2)], 2) # CLINKER -> PPC
push!(incoming_connections[(3, 2)], 3) # CLINKER -> PPC
push!(incoming_connections[(3, 2)], 4) # CLINKER -> PPC

push!(incoming_connections[(4, 1)], 1) # opc -> Warehouse
push!(incoming_connections[(4, 2)], 2) # ppc -> Warehouse


# outgoing connections
outgoing_connections = Dict{Tuple{Int,Int},Vector{Int}}()

# Initialize dictionary for all nodes in echelons 2 to max(E)
for e in eachindex(N)  # `eachindex(N)` provides safe iteration
    for node in N[e]
        outgoing_connections[(e, node)] = Int[]  # Start with an empty list
    end
end

#echelon 1
push!(outgoing_connections[(1, 1)], 1)
push!(outgoing_connections[(1, 1)], 2)
push!(outgoing_connections[(1, 2)], 2)
push!(outgoing_connections[(1, 3)], 2)
push!(outgoing_connections[(1, 4)], 2)
push!(outgoing_connections[(1, 5)], 2)

#echelon 2
push!(outgoing_connections[(2, 1)], 1)
push!(outgoing_connections[(2, 2)], 1)
push!(outgoing_connections[(2, 2)], 2)
push!(outgoing_connections[(2, 3)], 1)
push!(outgoing_connections[(2, 3)], 2)
push!(outgoing_connections[(2, 4)], 2)

#echelon 3
push!(outgoing_connections[(3, 1)], 1)
push!(outgoing_connections[(3, 2)], 2)



###############################################################################
# 2. Parameters
###############################################################################
# Demand: d[e, n, t] at each node (n) in each echelon (e), in each period (t).
combinations = [(e, n, t) for e in E for n in N[e] for t in Tset]
d = Dict(comb => 0.0 for comb in combinations)



# NO EXTERNAL DEMAND FOR INTERMEDIATE NODES

#demand for OPC
d[(4, 1, 1)] = 70000.0
d[(4, 1, 2)] = 70000.0
d[(4, 1, 3)] = 70000.0
d[(4, 1, 4)] = 70000.0
d[(4, 1, 5)] = 70000.0
d[(4, 1, 6)] = 70000.0

#demand for PPC
d[(4, 2, 1)] = 70000.0
d[(4, 2, 2)] = 70000.0
d[(4, 2, 3)] = 70000.0
d[(4, 2, 4)] = 70000.0
d[(4, 2, 5)] = 70000.0
d[(4, 2, 6)] = 70000.0

#CONSUMPTION PATTERNS:
alpha_combo = [(e, n, m) for e in 2:K for n in N[e] for m in N[e-1]]
alpha = Dict(combo => 0.0 for combo in alpha_combo)

alpha[(2, 1, 1)] = 0.048
alpha[(2, 2, 1)] = 1.378
alpha[(2, 2, 2)] = 0.0298
alpha[(2, 2, 3)] = 0.057
alpha[(2, 2, 4)] = 0.0815
alpha[(2, 2, 5)] = 0.00657
alpha[(3, 1, 1)] = 0.048
alpha[(3, 1, 2)] = 0.877
alpha[(3, 1, 3)] = 0.073
alpha[(3, 2, 2)] = 0.652
alpha[(3, 2, 3)] = 0.074
alpha[(3, 2, 3)] = 0.270



# Production Costs c[e,n,t]
c = Dict(comb => 0.0 for comb in combinations)

for t in Tset
    c[(1, 1, t)] = 7.99
    c[(1, 2, t)] = 6.89
    c[(1, 3, t)] = 9.18
    c[(1, 4, t)] = 28.69
    c[(1, 5, t)] = 61.6
end

# Holding Cost
combo_holding = [(e, n) for e in E for n in N[e]]
h = Dict(comb => 0.0 for comb in combo_holding)

for n in N[1]
    h[(1, n)] = 0.14
end

h[(2, 1)] = 0.14 #USD per tonne per two months (1 period)
h[(2, 2)] = 0.14
h[(2, 3)] = 0.14
h[(2, 4)] = 0.14
h[(3, 1)] = 0.14
h[(3, 2)] = 0.14
h[(4, 1)] = 2.09
h[(4, 2)] = 2.09

#Production/Shipping Capacity
Cap = Dict(comb => 5000.0 for comb in combinations)

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

s = Dict(comb => 4.49 for comb in combo_shipping)


# ELECTRICITY PRICES
elec_usage = Dict(comb => 0.0 for comb in combo_holding)
elec_usage[(2, 2)] = 56.72
elec_usage[(3, 1)] = 39.9
elec_usage[(3, 2)] = 30.6
elec_usage[(2, 2)] = 2.5

# Suppose electricity price changes each period
elec_price = Dict(t => 0.0 for t in Tset)
elec_price[1] = 0.088   # e.g. $0.10 per kWh
elec_price[2] = 0.074
elec_price[3] = 0.074
elec_price[4] = 0.066
elec_price[5] = 0.075
elec_price[6] = 0.075

###############################################################################
# 3. Build Model
###############################################################################
model = Model(Gurobi.Optimizer)

@variable(model, x[e in E, n in N[e], t in Tset] >= 0)
@variable(model, I[e in E, n in N[e], t in 0:maximum(Tset)] >= 0)
@variable(model, J[e in E, n in N[e], m in incoming_connections[(e, n)], t in 0:maximum(Tset)] >= 0)
@variable(model, f[e in E[1:end-1], n in N[e], m in N[e+1], t in 0:maximum(Tset)] >= 0)

@objective(model, Min,
    sum(
        # other production cost
        c[(e, n, t)] * x[e, n, t]
        +
        # electricity cost for producing x[e,n,t]
        elec_usage[(e, n)] * elec_price[t] * x[e, n, t]
        +
        # holding cost
        h[(e, n)] * I[e, n, t]
        for e in E, n in N[e], t in Tset
    )
    +
    sum(
        s[(e, n, m, t)] * f[e, n, m, t]
        for e in E[1:end-1], n in N[e], m in outgoing_connections[(e, n)], t in Tset
    )
)

# (A) Initial/final inventory = 0
for e in E
    for n in N[e]
        @constraint(model, I[e, n, 0] == 0)
        # @constraint(model, I[e, n, maximum(Tset)] == 0)

        for m in incoming_connections[(e, n)]
            @constraint(model, J[e, n, m, 0] == 0)
            # @constraint(model, J[e, n, m, maximum(Tset)] == 0)
        end
    end
end

# (B1) Flow/inventory balance for MANUFACTURING NODES

for e in 1:K
    for n in N[e]
        for t in Tset
            outbound = (e == maximum(E)) ? 0 : sum(f[e, n, m, t] for m in outgoing_connections[(e, n)])
            @constraint(model,
                I[e, n, t-1] + x[e, n, t]
                ==
                I[e, n, t] + outbound
            )

            if e > 1 > 0
                for m in incoming_connections[(e, n)]
                    @constraint(model,
                        J[e, n, m, t-1] + f[e-1, m, n, t]
                        ==
                        J[e, n, m, t] + alpha[e, n, m] * x[e, n, t]
                    )
                end
            end
        end
    end
end

# (B2) Flow/inventory balance for NON MANUFACTURING NODES
for e in K+1:E_max
    for n in N[e]
        for t in Tset
            inbound = (e == 1) ? 0 : sum(f[e-1, j, n, t] for j in incoming_connections[(e, n)])
            outbound = (e == maximum(E)) ? 0 : sum(f[e, n, m, t] for m in outgoing_connections[(e, n)])
            @constraint(model,
                I[e, n, t-1] + inbound
                ==
                I[e, n, t] + outbound + d[(e, n, t)]
            )
        end
    end
end


# # (C) Production capacity
# for e in E, n in N[e], t in Tset
#     @constraint(model, x[e, n, t] <= Cap[(e, n, t)])
# end

# # (D) (Optional) shipping capacity
# for e in E[1:end-1], n in N[e], m in N[e+1], t in Tset
#     @constraint(model, f[e, n, m, t] <= 100.0)
# end

JuMP.write_to_file(model, "model_constraints.lp")

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

# Time sets
time_prod = Tset           # For production and shipping, use t = 1:6
time_inv = 0:maximum(Tset) # For inventory, note that t starts at 0

########################################################################
# 1. Plot Production (x): for each echelon and each node
########################################################################
for e in E
    for n in N[e]
        # Extract production values over time
        prod = [value(x[e, n, t]) for t in time_prod]

        # Create a line plot for production
        p = plot(time_prod, prod,
            marker=:circle,
            lw=2,
            label="Production",
            title="Production at Echelon $e, Node $n",
            xlabel="Time Period",
            ylabel="Production")

        # Save the plot as a PNG file in the designated folder
        savefig(p, "img/cement/production_e$(e)_node$(n).png")
    end
end

########################################################################
# 2. Plot Inventory (I): for each echelon and each node
########################################################################
for e in E
    for n in N[e]
        # Extract inventory values over time (including period 0)
        inv = [value(I[e, n, t]) for t in time_inv]

        # Create a line plot for inventory
        p = plot(time_inv, inv,
            marker=:circle,
            lw=2,
            label="Inventory",
            title="Inventory at Echelon $e, Node $n",
            xlabel="Time Period",
            ylabel="Inventory")

        # Save the plot as a PNG file
        savefig(p, "img/cement/inventory_e$(e)_node$(n).png")
    end
end

########################################################################
# 3. Plot Shipping Flows (f): for each node in each echelon (except the last)
#    Plot all shipping flows from the node (one line per destination node)
########################################################################
for e in 1:(E_max-1)  # only echelons that ship to a subsequent echelon
    for n in N[e]
        # Only plot if there are defined outgoing connections
        if !isempty(outgoing_connections[(e, n)])
            # Create an empty plot
            p = plot(title="Shipping Flows from Echelon $e, Node $n",
                xlabel="Time Period",
                ylabel="Shipping Flow")

            # Loop over each outgoing connection (destination node in echelon e+1)
            for m in outgoing_connections[(e, n)]
                # Extract shipping flow values over time
                flow = [value(f[e, n, m, t]) for t in time_prod]
                # Add a line for this destination node
                plot!(p, time_prod, flow,
                    marker=:circle,
                    lw=2,
                    label="To Node $m (Echelon $(e+1))")
            end

            # Save the shipping flows plot as a PNG file
            savefig(p, "img/cement/shipping_e$(e)_node$(n).png")
        end
    end
end

########################################################################
# 4. Plot Electricity Prices over Time
########################################################################
# Electricity prices are stored in the dictionary elec_price.
# We assume elec_price[t] is defined for each period in Tset.
elec_prices = [elec_price[t] for t in Tset]

p_elec = plot(Tset, elec_prices,
    marker=:circle,
    lw=2,
    label="Electricity Price",
    title="Electricity Prices over Time",
    xlabel="Time Period",
    ylabel="Price (\$/kWh)",
    legend=:topright)

# Save the electricity prices plot
savefig(p_elec, "img/cement/electricity_prices.png")
