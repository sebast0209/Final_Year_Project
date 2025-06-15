using JuMP
using Gurobi
using MathOptInterface
const MOI = MathOptInterface
using Plots
using XLSX, DataFrames, Dates, Statistics, FileIO


function run_scenario(file_path::String, tag::String, prod_caps::Dict{Tuple{Int,Int},Float64}, inv_cap_up::Float64, inv_cap_down::Float64)
    println("  → Node production capacities for '$tag':")
    for ((e, n), cap) in sort(collect(prod_caps))
        println("     Node ($e, $n): $(round(cap, digits=2))")
    end

    ###############################################################################
    # 1. Load Electricity Prices from NREL CAMBIUM Dataset (Hourly Data)
    ###############################################################################
    #load the data from 2050
    file_path = file_path
    df = DataFrame(XLSX.readtable(file_path, 1))  # Reads first sheet
    df = select(df, 1:4)
    # df = df[1:24, :]


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
    E_max = 5
    E = 1:E_max

    #Time periods
    Tset = 1:num_hours

    # Manufacturing nodes
    K = 3

    # Nodes at each echelon
    N = Dict(
        1 => 1:5,
        2 => 1:5,
        3 => 1:2,
        4 => 1:5,
        5 => 1:15
    )

    # Two types of products in downstream SC (OPC and PPC)
    P = 1:2 # 1 is OPC, 2 is PPC

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
    push!(incoming_connections[(3, 1)], 5)  # jarosite -> OPC

    push!(incoming_connections[(3, 2)], 2)  # CLINKER -> PPC
    push!(incoming_connections[(3, 2)], 3)
    push!(incoming_connections[(3, 2)], 4)
    push!(incoming_connections[(3, 2)], 5)

    # Echelon 4

    for i in N[3]
        for j in N[4]
            push!(incoming_connections[(4, j)], i)
        end
    end

    #Echelon 5
    for i in N[4]
        for j in N[5]
            push!(incoming_connections[(5, j)], i)
        end
    end


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
    push!(outgoing_connections[(2, 5)], 1)
    push!(outgoing_connections[(2, 5)], 2)

    # Echelon 3 outgoing
    for i in N[3]
        for j in N[4]
            push!(outgoing_connections[(3, i)], j)
        end
    end

    #Echelon 4 outgoing
    for i in N[4]
        for j in N[5]
            push!(outgoing_connections[(4, i)], j)
        end
    end

    # Demand
    d = Dict{Tuple{Int,Int,Int,Int},Float64}()
    for e in K+1:E_max-1
        for n in N[e], p in P, t in Tset
            d[(e, n, p, t)] = 0.0
        end
    end

    for n in N[E_max], p in P, t in Tset
        d[(E_max, n, p, t)] = 15000000.0 / (2 * num_hours * 15)
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
    alpha[(3, 1, 5)] = 0.002
    alpha[(3, 2, 2)] = 0.652
    alpha[(3, 2, 3)] = 0.074
    alpha[(3, 2, 4)] = 0.270
    alpha[(3, 2, 5)] = 0.004

    # --- Production Costs ---
    # assume that non-electricity costs are 60% of market price [350 rupee per 50kg bag] -> 80USD/t, 
    #profit margin for others about 75% because include electricity
    combinations = [(e, n, t) for e in E for n in N[e] for t in Tset]
    c = Dict(comb => 0.0 for comb in combinations)
    for t in Tset
        c[(1, 1, t)] = 7.99
        c[(1, 2, t)] = 6.89
        c[(1, 3, t)] = 9.18
        c[(1, 4, t)] = 28.69
        c[(1, 5, t)] = 61.6
        c[(2, 1, t)] = 12.0 #48/4 processes
        c[(2, 2, t)] = 12.0
        c[(2, 3, t)] = 15.16 * 0.75 #https://www.indiamart.com/proddetail/gypsum-for-aac-blocks-15755182897.html
        c[(2, 4, t)] = 5.83 * 0.75 #https://www.indiamart.com/proddetail/fly-ash-19388851433.html
        c[(2, 5, t)] = 2.0 #free, waste product
        c[(3, 1, t)] = 12.0
        c[(3, 2, t)] = 12.0
    end

    # --- Holding Cost ---
    combo_holding = [(e, n) for e in E for n in N[e]]
    h = Dict(comb => 0.0 for comb in combo_holding)
    for n in N[1]
        h[(1, n)] = 0.50 / num_hours
    end
    h[(2, 1)] = 0.70 / num_hours
    h[(2, 2)] = 0.70 / num_hours
    h[(2, 3)] = 0.50 / num_hours
    h[(2, 4)] = 0.50 / num_hours
    h[(2, 5)] = 0.50 / num_hours
    h[(3, 1)] = 0.70 / num_hours
    h[(3, 2)] = 0.70 / num_hours
    for i in N[4]
        h[(4, i)] = 2.50 / num_hours #assumed
    end
    for i in N[5]
        h[(5, i)] = 2.50 / num_hours #assumed
    end

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
    s = Dict(comb => 0.0 for comb in combo_shipping)
    # --Shipping costs
    #E1->E2
    for n in N[1]
        for m in N[2]
            for t in Tset
                s[(1, n, m, t)] = 10.0 #$/tonne
            end
        end
    end
    for t in Tset
        s[(2, 3, 1, t)] = 10.0 #$/tonne
        s[(2, 3, 2, t)] = 10.0 #$/tonne
        s[(2, 4, 2, t)] = 10.0 #$/tonne
        s[(2, 5, 2, t)] = 1.0 #$/tonne
        s[(2, 5, 1, t)] = 1.0 #$/tonne
    end
    #E3->E4
    for n in N[3]
        for m in N[4]
            for t in Tset
                s[(3, n, m, t)] = 20.0 #$/tonne
            end
        end
    end
    #E4->E5
    for n in N[4]
        for m in N[5]
            for t in Tset
                s[(4, n, m, t)] = 5.0 #$/tonne (half of warehouse to wholesaler)
            end
        end
    end

    # --- Electricity Usage & Prices ---
    elec_usage = Dict(comb => 0.0 for comb in combo_holding)
    elec_usage[(2, 1)] = 1.77
    elec_usage[(2, 2)] = 56.72
    elec_usage[(3, 1)] = 39.9
    elec_usage[(3, 2)] = 30.6

    startup_cost = 5000.0

    # --- Capacity investment costs ---
    #9368/24
    combo_producing = [(e, n) for e in 1:K for n in N[e]]
    capacity_cost_prod = Dict(comb => 500.0 for comb in combo_producing)
    capacity_cost_storage = Dict{Tuple{Int,Int},Float64}()
    # bulk silo for manufacturing
    for e in 1:K, n in N[e]
        capacity_cost_storage[(e, n)] = 7.0
    end
    # bagged for downstream
    for e in K+1:E_max, n in N[e]
        capacity_cost_storage[(e, n)] = 25.0
    end

    # --DEFINE THE MODEL---
    model = Model(Gurobi.Optimizer)

    @variable(model, x[e in E, n in N[e], t in Tset] >= 0)
    @variable(model, I[e in 1:K, n in N[e], t in 0:maximum(Tset)] >= 0)
    @variable(model, J[e in K+1:E_max, n in N[e], p in P, t in 0:maximum(Tset)] >= 0)
    @variable(model, f_up[e in 1:K-1, n in N[e], m in N[e+1],
        t in 0:maximum(Tset)] >= 0)

    @variable(model, f_down[e in K:E_max-1, n in N[e], m in N[e+1], p in P,
        t in 0:maximum(Tset)] >= 0)

    @variable(model, y[e in 2:K, n in N[e], t in Tset], Bin)
    @variable(model, z[e in 1:K, n in N[e], t in 2:num_hours], Bin)

    @objective(model, Min,
        # 1) production + electricity + holding in upstream
        sum(
            c[(e, n, t)] * x[e, n, t] +
            (h[(e, n)] * I[e, n, t]) +
            (haskey(elec_usage, (e, n)) ? elec_usage[(e, n)] * elec_price[t] * x[e, n, t] : 0.0)
            for e in 1:K, n in N[e], t in Tset
        )
        + # 2) holding downstream in J
        sum(h[(e, n)] * J[e, n, p, t] for e in K+1:E_max, n in N[e], p in P, t in Tset)
        + # 3) shipping upstream on f_up
        sum(s[(e, n, m, t)] * f_up[e, n, m, t]
            for e in 1:K-1, n in N[e], m in outgoing_connections[(e, n)], t in Tset)
        + # 4) shipping downstream on f_down
        sum(s[(e, n, m, t)] * f_down[e, n, m, p, t]
            for e in K:E_max-1, n in N[e], m in outgoing_connections[(e, n)], p in P, t in Tset)
        + # 5) startup costs
        startup_cost * sum(z[e, n, t] for e in 2:K, n in N[e], t in 2:num_hours)
    )

    # (B1) Flow/Inventory Balance for Manufacturing Nodes (Echelons 1 to K)
    for e in 1:K-1
        for n in N[e]
            for t in Tset
                outbound = (e == maximum(E)) ? 0 : sum(f_up[e, n, m, t] for m in outgoing_connections[(e, n)])
                @constraint(model,
                    I[e, n, t-1] + x[e, n, t] == I[e, n, t] + outbound
                )
                if e > 1
                    for m in incoming_connections[(e, n)]
                        @constraint(model,
                            f_up[e-1, m, n, t] == alpha[(e, n, m)] * x[e, n, t]
                        )
                    end
                end
            end
        end
    end

    #(B1*) at echelon K (transition from manufacturing to non-manufacturing)
    for n in N[K], m in outgoing_connections[(K, n)], p in P, t in Tset
        if p != n
            @constraint(model, f_down[K, n, m, p, t] == 0)
        end
    end

    for n in N[K]
        for t in Tset
            outbound = sum(f_down[K, n, m, n, t] for m in outgoing_connections[(K, n)])
            @constraint(model,
                I[K, n, t-1] + x[K, n, t] == I[K, n, t] + outbound
            )
            for m in incoming_connections[(K, n)]
                @constraint(model,
                    f_up[K-1, m, n, t] == alpha[(K, n, m)] * x[K, n, t]
                )
            end
        end
    end



    # (B2) Flow/Inventory Balance for Non-Manufacturing Nodes (Echelons K+1 to E_max)
    for e in (K+1):E_max
        for n in N[e]
            for t in Tset
                for p in P
                    inbound = (e == 1) ? 0 : sum(f_down[e-1, j, n, p, t] for j in incoming_connections[(e, n)])
                    outbound = (e == E_max) ? 0 : sum(f_down[e, n, m, p, t] for m in outgoing_connections[(e, n)])
                    @constraint(model,
                        J[e, n, p, t-1] + inbound == J[e, n, p, t] + outbound + d[e, n, p, t]
                    )
                end

            end
        end
    end

    # (C) Ramping Constraints
    ramp_up = Dict((e, n) => 200.0 for e in 2:3 for n in N[e])
    ramp_down = Dict((e, n) => 200.0 for e in 2:3 for n in N[e])

    for e in 2:3, n in N[e], t in 2:num_hours
        @constraint(model, x[e, n, t] - x[e, n, t-1] <= ramp_up[(e, n)])
        @constraint(model, x[e, n, t-1] - x[e, n, t] <= ramp_down[(e, n)])
    end

    # (D) On Off Decisions
    for e in 2:K, n in N[e], t in Tset
        if haskey(prod_caps, (e, n))
            cap = prod_caps[(e, n)]
            @constraint(model, x[e, n, t] <= cap * y[e, n, t])
        else
            @constraint(model, x[e, n, t] <= 1e8 * y[e, n, t])  # fallback if not specified
        end
    end
    for e in 2:K, n in N[e], t in 2:num_hours
        @constraint(model, z[e, n, t] >= y[e, n, t] - y[e, n, t-1])
    end

    # (F) Zero Initial Inventory
    for e in 1:K, n in N[e]
        @constraint(model, I[e, n, 0] == 0)
    end
    # downstream echelons:
    for e in K+1:E_max, n in N[e], p in P
        @constraint(model, J[e, n, p, 0] == 0)
    end

    # (E) Capacity Constraints
    for e in 1:K, n in N[e], t in Tset
        @constraint(model, I[e, n, t] <= inv_cap_up)
    end

    for e in K+1:E_max, n in N[e], p in P, t in Tset
        @constraint(model, J[e, n, p, t] <= inv_cap_down)
    end

    optimize!(model)

    CAPEX_OPEX = 0.0

    # 6) Capacity investment: production
    for n in N[K]
        CAPEX_OPEX += capacity_cost_prod[(K, n)] * prod_caps[K, n]
    end

    # 7) Capacity investment: storage
    for e in 1:K, n in N[e]
        CAPEX_OPEX += capacity_cost_storage[(e, n)] * inv_cap_up
    end
    for e in K+1:E_max, n in N[e]
        CAPEX_OPEX += capacity_cost_storage[(e, n)] * inv_cap_down
    end

    obj_val = objective_value(model)
    CAPEX_OPEX += obj_val


    return obj_val, CAPEX_OPEX
end

#-----------------------------------------------------------------
# EXPERIMENTS
#-----------------------------------------------------------------

const INPUT_FILE = "../data/CAISO_MC_2050.xlsx"
baseline_prod_cap = Dict(
    (2, 1) => 41.5,
    (2, 2) => 1310.0,
    (2, 3) => 126.0,
    (2, 4) => 232.0,
    (3, 1) => 857.0,
    (3, 2) => 857.0
)  # → demand‐matching capacity of clinker

# ─────────────────────────────────────────────────────────────────────────────
# 3) EXPERIMENT 1:
#
#    Hold inv_cap_up = inv_cap_down = 1e8
#    Vary prod_cap over the “scenarios” defined in your original code
#    (baseline, 1.5×, 2×, 3×, 5×, 7×, 10×, 15×).
#    Store the objective value for each run in a DataFrame and write
#    to “experiment1.xlsx”.
# ─────────────────────────────────────────────────────────────────────────────
experiment1_tags = Dict(
    "baseline" => 1.0,
    "high1.5x" => 1.5,
    "high2x" => 2.0,
    "high3x" => 3.0,
    "high5x" => 5.0,
    "high7x" => 7.0,
    "high10x" => 10.0,
    "high15x" => 15.0
)

# Prepare a DataFrame to hold (Tag, ProdCap, InvCapUp, InvCapDown, ObjValue, CAPEX_OPEX)
df1 = DataFrame(
    Tag=String[],
    ProdCap=Float64[],
    InvCapUp=Float64[],
    InvCapDown=Float64[],
    ObjValue=Float64[],
    CAPEX_OPEX=Float64[]
)

for (tag, factor) in experiment1_tags
    println("Running Experiment 1, scenario with ProdCap = $(round(factor, digits=2)) …")
    scaled_caps = Dict(k => v * factor for (k, v) in baseline_prod_cap)
    # Make sure your function returns both values
    obj, capex_opex = run_scenario(INPUT_FILE, tag, scaled_caps, 1e8, 1e8)

    # Add results to df1
    push!(df1, (tag, factor, 1e8, 1e8, obj, capex_opex))
end

mkpath("OPEX_capacity_experiments/results")

# Write Experiment 1 results to Excel
XLSX.writetable("OPEX_capacity_experiments/results/experiment1a.xlsx", Tables.columntable(df1);
    sheetname="Exp1_Results")

println("✓ Experiment 1 results saved → experiment1a.xlsx")

# ─────────────────────────────────────────────────────────────────────────────
# 4) EXPERIMENT 2:
#
#    Hold prod_cap = 2×baseline_prod_cap
#         inv_cap_down = 1e8
#    Vary inv_cap_up = 10^1, 10^2, 10^3, …, 10^8
#    Store “InvCapUp” vs. objective in a DataFrame → “experiment2.xlsx”
# ─────────────────────────────────────────────────────────────────────────────
experiment2_prod_cap = Dict(k => v * 5.0 for (k, v) in baseline_prod_cap)
experiment2_invcapdown = 1e8

# Prepare DataFrame: (InvCapUp, ProdCap, InvCapDown, ObjValue, CAPEX_OPEX)
df2 = DataFrame(
    InvCapUp=Float64[],
    ProdCap=Float64[],
    InvCapDown=Float64[],
    ObjValue=Float64[],
    CAPEX_OPEX=Float64[]
)


for power in 0:10
    icu = 10.0^power  # 10^1, 10^2, …, 10^10
    tag = "exp2_up$(power)"  # e.g. “exp2_up1”, “exp2_up2”, etc.
    println("Running Experiment 2, inv_cap_up = $(icu) (10^$power) …")

    # Assumes run_scenario returns both values
    obj, capex_opex = run_scenario(INPUT_FILE, tag, experiment2_prod_cap, icu, experiment2_invcapdown)

    total_cap2 = sum(values(experiment2_prod_cap))
    push!(df2, (icu, 5.0, experiment2_invcapdown, obj, capex_opex))
end

# Write Experiment 2 results to Excel
mkpath("OPEX_capacity_experiments/results")
XLSX.writetable("OPEX_capacity_experiments/results/experiment2a.xlsx", Tables.columntable(df2);
    sheetname="Exp2_Results")

println("✓ Experiment 2 results saved → experiment2a.xlsx")


# ─────────────────────────────────────────────────────────────────────────────
# 5) EXPERIMENT 3:
#
#    Hold prod_cap   = 2×baseline_prod_cap
#         inv_cap_up = 1e8
#    Vary inv_cap_down = 10^1, 10^2, 10^3, …, 10^8
#    Store “InvCapDown” vs. objective in a DataFrame → “experiment3.xlsx”
# ─────────────────────────────────────────────────────────────────────────────
experiment3_prod_cap = Dict(k => v * 5.0 for (k, v) in baseline_prod_cap)
experiment3_invcapup = 1e8

# Prepare DataFrame: (InvCapDown, ProdCap, InvCapUp, ObjValue, CAPEX_OPEX)
df3 = DataFrame(
    InvCapDown=Float64[],
    ProdCap=Float64[],
    InvCapUp=Float64[],
    ObjValue=Float64[],
    CAPEX_OPEX=Float64[]
)

for power in 0:8
    icd = 10.0^power  # 10^1, 10^2, …, 10^8
    tag = "exp3_down$(power)"
    println("Running Experiment 3, inv_cap_down = $(icd) (10^$power) …")

    # Make sure run_scenario returns both values
    obj, capex_opex = run_scenario(INPUT_FILE, tag, experiment3_prod_cap, experiment3_invcapup, icd)

    total_cap3 = sum(values(experiment3_prod_cap))
    push!(df3, (icd, 5.0, experiment3_invcapup, obj, capex_opex))
end

# Write Experiment 3 results to Excel
mkpath("OPEX_capacity_experiments/results")
XLSX.writetable("OPEX_capacity_experiments/results/experiment3a.xlsx", Tables.columntable(df3);
    sheetname="Exp3_Results")

println("✓ Experiment 3 results saved → experiment3a.xlsx")
