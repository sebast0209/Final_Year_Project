using JuMP
using Gurobi
using MathOptInterface
const MOI = MathOptInterface
using Plots
using XLSX, DataFrames, Dates, Statistics, FileIO

###############################################################################
# 1. Load Electricity Prices from NREL CAMBIUM Dataset (Hourly Data)
###############################################################################
save_path = "img/2050_hourly"
mkpath(save_path)  # Create directory if it doesn't exist

# Load the Excel file
file_path = "../data/CAISO_MC_2050.xlsx"
df = DataFrame(XLSX.readtable(file_path, 1))  # Reads first sheet
df = select(df, 1:4)

# Rename columns for consistency
rename!(df, [:timestamp, :total_cost_enduse, :generation, :variable_generation])

# println(first(df, 5))

# Convert cost units (original data in MWh)
df.total_cost_enduse ./= 1000

# Renewable Pnetration calculation
variable = df[!, "variable_generation"]
total = df[!, "generation"]
# penetration = [t > 0 ? v / t : 0.0 for (v, t) in zip(variable, total)]
len = 1:nrow(df)

# Use the hourly data directly
elec_price = df.total_cost_enduse
num_hours = nrow(df)
x_indices = 1:num_hours

mean_price = mean(elec_price)

###############################################################################
# 2. INPUTS: Define Sets, Parameters, and Data
###############################################################################

# Echelons
E_max = 4
E = 1:E_max

# Time periods
Tset = 1:num_hours

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
    d[(4, 1, t)] = 1200000.0 / (2 * num_hours)  # OPC demand
    d[(4, 2, t)] = 1200000.0 / (2 * num_hours) # PPC demand
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
    h[(1, n)] = 0.83 / num_hours
end
h[(2, 1)] = 0.83 / num_hours
h[(2, 2)] = 0.83 / num_hours
h[(2, 3)] = 0.83 / num_hours
h[(2, 4)] = 0.83 / num_hours
h[(3, 1)] = 0.83 / num_hours
h[(3, 2)] = 0.83 / num_hours
h[(4, 1)] = 2.09 / num_hours
h[(4, 2)] = 2.09 / num_hours

# --- Production/Shipping Capacity ---
# Cap = Dict(comb => (4000.0 / 24) for comb in combinations)

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
elec_usage[(2, 1)] = 1.77
elec_usage[(2, 2)] = 56.72
elec_usage[(3, 1)] = 39.9
elec_usage[(3, 2)] = 30.6

startup_cost = 5000.0

function run_scenario(capacity_2_2::Float64, tag::String)
    E_max = 4
    E = 1:E_max

    # ---------------------- 1. INPUTS / SETS / DATA ------------------------
    # **everything** you already have up to the point where you define `Cap`
    # stays the same, except for the block right below.

    # ---- Production / shipping capacity dictionary ----
    Cap = Dict(comb => 4000.0 / 24 for comb in combinations)
    startup_cost = 5000.0

    # >>>> override the kiln we want to size
    for t in Tset
        Cap[(2, 2, t)] = capacity_2_2          # <-- the new value
    end

    # ---------------------------- 2.  MODEL -------------------------------
    model = Model(Gurobi.Optimizer)

    @variable(model, x[e in E, n in N[e], t in Tset] >= 0)
    @variable(model, I[e in E, n in N[e], t in 0:maximum(Tset)] >= 0)
    @variable(model, J[e in E, n in N[e],
        m in incoming_connections[(e, n)],
        t in 0:maximum(Tset)] >= 0)
    @variable(model, f[e in E[1:end-1], n in N[e], m in N[e+1],
        t in 0:maximum(Tset)] >= 0)
    @variable(model, y[e in 2:3, n in N[e], t in Tset], Bin)
    @variable(model, z[e in 1:3, n in N[e], t in 2:num_hours], Bin)

    @objective(model, Min,
        # Production and holding costs
        sum(
            c[(e, n, t)] * x[e, n, t] +
            elec_usage[(e, n)] * elec_price[t] * x[e, n, t] +
            h[(e, n)] * I[e, n, t]
            for e in E, n in N[e], t in Tset
        )
        +
        # Shipping costs
        sum(
            s[(e, n, m, t)] * f[e, n, m, t]
            for e in E[1:end-1], n in N[e], m in outgoing_connections[(e, n)], t in Tset
        )
        +
        #startup cost
        startup_cost * sum(z[e, n, t] for e in 2:3, n in N[e], t in 2:num_hours)
    )

    # Initial Conditions: Inventory and Flow start at zero
    for e in E
        for n in N[e]
            @constraint(model, I[e, n, 0] == 0)
            for m in incoming_connections[(e, n)]
                @constraint(model, J[e, n, m, 0] == 0)
            end
        end
    end

    # (B1) Flow/Inventory Balance for Manufacturing Nodes (Echelons 1 to K)
    for e in 1:K
        for n in N[e]
            for t in Tset
                outbound = (e == maximum(E)) ? 0 : sum(f[e, n, m, t] for m in outgoing_connections[(e, n)])
                @constraint(model,
                    I[e, n, t-1] + x[e, n, t] == I[e, n, t] + outbound
                )
                if e > 1
                    for m in incoming_connections[(e, n)]
                        @constraint(model,
                            J[e, n, m, t-1] + f[e-1, m, n, t] == J[e, n, m, t] + alpha[(e, n, m)] * x[e, n, t]
                        )
                    end
                end
            end
        end
    end

    # (B2) Flow/Inventory Balance for Non-Manufacturing Nodes (Echelons K+1 to E_max)
    for e in (K+1):E_max
        for n in N[e]
            for t in Tset
                inbound = (e == 1) ? 0 : sum(f[e-1, j, n, t] for j in incoming_connections[(e, n)])
                outbound = (e == maximum(E)) ? 0 : sum(f[e, n, m, t] for m in outgoing_connections[(e, n)])
                @constraint(model,
                    I[e, n, t-1] + inbound == I[e, n, t] + outbound + d[(e, n, t)]
                )
            end
        end
    end

    # (C) Ramping Constraints
    ramp_up = Dict((e, n) => 5.0 for e in 2:3 for n in N[e])
    ramp_down = Dict((e, n) => 5.0 for e in 2:3 for n in N[e])

    for e in 2:3, n in N[e], t in 2:num_hours
        @constraint(model, x[e, n, t] - x[e, n, t-1] <= ramp_up[(e, n)])
        @constraint(model, x[e, n, t-1] - x[e, n, t] <= ramp_down[(e, n)])
    end

    # (D) On Off Decisions
    for e in 2:3, n in N[e], t in Tset
        @constraint(model, x[e, n, t] <= Cap[(e, n, t)] * y[e, n, t])
    end
    startup_cost = 50.0
    for e in 2:3, n in N[e], t in 2:num_hours
        @constraint(model, z[e, n, t] >= y[e, n, t] - y[e, n, t-1])
    end

    optimize!(model)

    # --------------------------- 3.  EXPORT -------------------------------
    energy_over_time = [sum(elec_usage[(e, n)] * value(x[e, n, t]) / 1000
                            for e in 1:3 for n in N[e]) for t in Tset]
    production_3_1 = [value(x[3, 1, t]) for t in Tset]
    production_2_2 = [value(x[2, 2, t]) for t in Tset]
    production_cost = objective_value(model)

    df = DataFrame(Time_Period=Tset,
        Energy_Consumption_MWh=energy_over_time,
        Production_3_1_tonnes=production_3_1,
        Production_2_2_tonnes=production_2_2,
        Production_Cost=production_cost,
    )

    mkpath("capacity_experiments/results")
    out_file = "capacity_experiments/results/prod_energy_cons_$(tag).xlsx"
    XLSX.writetable(out_file, Tables.columntable(df); sheetname="Series")
    println("✓ Scenario $(tag) saved → $(out_file)")
end

baseline_cap = 1200000.0 / (num_hours)   # = demand-matching capacity of clinker
scenarios = Dict(
    # "baseline" => baseline_cap,
    # "high1.5x" => 1.5 * baseline_cap,   # +50 %
    # "high2x" => 2 * baseline_cap,
    "high3x" => 3 * baseline_cap,
    # "high5x" => 5 * baseline_cap,
    "high7x" => 7 * baseline_cap,
    "high10x" => 10 * baseline_cap,
    "high15x" => 15 * baseline_cap,
)



for (tag, cap_val) in scenarios
    println("\n=== Running scenario $(tag) with capacity $(round(cap_val, digits = 2)) t/h ===")
    run_scenario(cap_val, tag)
end
