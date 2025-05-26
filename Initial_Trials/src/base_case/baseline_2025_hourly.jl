###############################################################################
# 0. Load Packages
###############################################################################
using JuMP
using Gurobi
using MathOptInterface
const MOI = MathOptInterface
using DataFrames, XLSX, Dates, Statistics, Plots

###############################################################################
# 1. Load Electricity Prices from NREL CAMBIUM Dataset
###############################################################################
save_path = "img/2025_no_storage_hourly"
mkpath(save_path)  # Create directory if it doesn't exist

# Load the Excel file (adjust the file_path if needed)
file_path = "../data/CAISO_MC_2025.xlsx"
df = DataFrame(XLSX.readtable(file_path, 1))  # Reads first sheet
df = select(df, 1:2)

# Rename columns for consistency
rename!(df, [:timestamp, :total_cost_enduse])

# Extract the date (ignoring time) and adjust cost units
df.date = Date.(df.timestamp)
df.total_cost_enduse ./= 1000

elec_price = df.total_cost_enduse
num_hours = nrow(df)
x_indices = 1:num_hours

num_days = length(elec_price)
Tset = 1:num_days

###############################################################################
# 2. INPUTS: Define Sets, Parameters, and Data
###############################################################################

# Echelons
E_max = 4
E = 1:E_max

# Time periods
Tset = 1:num_days

# Manufacturing echelons (first K echelons)
K = 3

# Nodes at each echelon
N = Dict(
    1 => 1:5,
    2 => 1:4,
    3 => 1:2,
    4 => 1:2
)

# --- Define incoming connections (from echelon e-1 to echelon e) ---
incoming_connections = Dict{Tuple{Int,Int},Vector{Int}}()
for e in eachindex(N)
    for node in N[e]
        incoming_connections[(e, node)] = Int[]  # Initialize as empty vector
    end
end

# Echelon 2
push!(incoming_connections[(2, 1)], 1)  # limestone -> crushed limestone
for node in N[1]                   # clinker production: all nodes of echelon 1
    push!(incoming_connections[(2, 2)], node)
end

# Echelon 3
push!(incoming_connections[(3, 1)], 1)  # crushed limestone -> OPC
push!(incoming_connections[(3, 1)], 2)  # CLINKER -> OPC
push!(incoming_connections[(3, 1)], 3)  # Gypsum -> OPC

push!(incoming_connections[(3, 2)], 2)  # CLINKER -> PPC
push!(incoming_connections[(3, 2)], 3)
push!(incoming_connections[(3, 2)], 4)

# Echelon 4
push!(incoming_connections[(4, 1)], 1)  # OPC -> Warehouse
push!(incoming_connections[(4, 2)], 2)  # PPC -> Warehouse

# --- Define outgoing connections ---
outgoing_connections = Dict{Tuple{Int,Int},Vector{Int}}()
for e in eachindex(N)
    for node in N[e]
        outgoing_connections[(e, node)] = Int[]
    end
end

# Echelon 1 outgoing
push!(outgoing_connections[(1, 1)], 1)
push!(outgoing_connections[(1, 1)], 2)
push!(outgoing_connections[(1, 2)], 2)
push!(outgoing_connections[(1, 3)], 2)
push!(outgoing_connections[(1, 4)], 2)
push!(outgoing_connections[(1, 5)], 2)

# Echelon 2 outgoing
push!(outgoing_connections[(2, 1)], 1)
push!(outgoing_connections[(2, 2)], 1)
push!(outgoing_connections[(2, 2)], 2)
push!(outgoing_connections[(2, 3)], 1)
push!(outgoing_connections[(2, 3)], 2)
push!(outgoing_connections[(2, 4)], 2)

# Echelon 3 outgoing
push!(outgoing_connections[(3, 1)], 1)
push!(outgoing_connections[(3, 2)], 2)

# --- Demand ---
combinations = [(e, n, t) for e in E for n in N[e] for t in Tset]
d = Dict(comb => 0.0 for comb in combinations)

# Only external demand is at the Warehouse (echelon 4)
for t in Tset
    d[(4, 1, t)] = 210000000.0 / (2 * num_days)  # OPC demand
    d[(4, 2, t)] = 210000000.0 / (2 * num_days) # PPC demand
end

# --- Consumption Patterns ---
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
alpha[(3, 2, 3)] = 0.270

# --- Production Costs ---
c = Dict(comb => 0.0 for comb in combinations)
for t in Tset
    c[(1, 1, t)] = 7.99
    c[(1, 2, t)] = 6.89
    c[(1, 3, t)] = 9.18
    c[(1, 4, t)] = 28.69
    c[(1, 5, t)] = 61.6
end

# --- Holding Cost ---
combo_holding = [(e, n) for e in E for n in N[e]]
h = Dict(comb => 0.0 for comb in combo_holding)
for n in N[1]
    h[(1, n)] = 0.83 / num_days
end
h[(2, 1)] = 0.83 / num_days
h[(2, 2)] = 0.83 / num_days
h[(2, 3)] = 0.83 / num_days
h[(2, 4)] = 0.83 / num_days
h[(3, 1)] = 0.83 / num_days
h[(3, 2)] = 0.83 / num_days
h[(4, 1)] = 2.09 / num_days
h[(4, 2)] = 2.09 / num_days

# --- Production/Shipping Capacity ---
Cap = Dict(comb => 5000.0 for comb in combinations)

# --- Shipping Cost ---
combo_shipping = []
for e in E
    if e + 1 in keys(N)
        for n in N[e]
            for m in N[e+1]
                for t in Tset
                    push!(combo_shipping, (e, n, m, t))
                end
            end
        end
    end
end
s = Dict(comb => 4.49 for comb in combo_shipping)

# --- Electricity Usage & Prices ---
elec_usage = Dict(comb => 0.0 for comb in combo_holding)
elec_usage[(2, 2)] = 2.5   # Note: This overwrites the previous value of 56.72
elec_usage[(3, 1)] = 39.9
elec_usage[(3, 2)] = 30.6


###############################################################################
# 3. MODEL: Build and Solve the JuMP Model (No Storage / Just-in-Time)
###############################################################################
# In this formulation, there are no inventory variables. Production in a
# period must immediately be shipped forward to either satisfy the next
# echelon’s input requirements (via conversion factors) or to meet demand.
model = Model(Gurobi.Optimizer)

# Decision Variables:
# Production at manufacturing nodes (Echelons 1 to 3)
@variable(model, x[e in 1:3, n in N[e], t in Tset] >= 0)
# Shipping flows for transitions from echelon e to echelon e+1
@variable(model, f[e in 1:3, n in N[e], m in outgoing_connections[(e, n)], t in Tset] >= 0)

# Balance Constraints:
# Echelon 1: Production equals shipping out.
for t in Tset, n in N[1]
    @constraint(model, x[1, n, t] == sum(f[1, n, m, t] for m in outgoing_connections[(1, n)]))
end

# Echelon 2: Production equals shipping out; input from echelon 1 is tied by conversion.
for t in Tset, n in N[2]
    @constraint(model, x[2, n, t] == sum(f[2, n, m, t] for m in outgoing_connections[(2, n)]))
    for m in incoming_connections[(2, n)]
        @constraint(model, f[1, m, n, t] == alpha[(2, n, m)] * x[2, n, t])
    end
end

# Echelon 3: Production equals shipping out; input from echelon 2 is tied by conversion.
for t in Tset, n in N[3]
    @constraint(model, x[3, n, t] == sum(f[3, n, m, t] for m in outgoing_connections[(3, n)]))
    for m in incoming_connections[(3, n)]
        @constraint(model, f[2, m, n, t] == alpha[(3, n, m)] * x[3, n, t])
    end
end

# Echelon 4 (Warehouse): Incoming shipments must meet the external demand.
for t in Tset, n in N[4]
    @constraint(model, sum(f[3, j, n, t] for j in incoming_connections[(4, n)]) == d[(4, n, t)])
end

# Objective Function:
# Minimize production cost (including electricity cost) plus shipping cost.
@objective(model, Min,
    sum((c[(e, n, t)] + elec_usage[(e, n)] * elec_price[t]) * x[e, n, t]
        for e in 1:3, n in N[e], t in Tset)
    +
    sum(s[(e, n, m, t)] * f[e, n, m, t]
        for e in 1:3, n in N[e], m in outgoing_connections[(e, n)], t in Tset)
)

optimize!(model)

println("Optimal Total Cost (No Storage, using Gurobi): ", objective_value(model))

###############################################################################
# 5. PRINT TOTAL ELECTRICITY COST
###############################################################################
# Compute the total electricity cost as the sum over all production nodes and time periods.
total_elec_cost = sum(elec_usage[(e, n)] * elec_price[t] * value(x[e, n, t])
                      for e in 1:3 for n in N[e] for t in Tset)
println("Total Electricity Cost: \$", round(total_elec_cost, digits=2))

###############################################################################
# 4. (Optional) Plot Production Results for Echelon 1 Nodes
###############################################################################
for n in N[1]
    prod = [value(x[1, n, t]) for t in Tset]
    p = plot(Tset, prod, lw=2, label="Production at Node $n",
        xlabel="Time Period", ylabel="Production",
        title="Echelon 1 Production at Node $n (No Storage)")
    savefig(p, "$(save_path)/production_e1_node$(n)_no_storage.png")
end
