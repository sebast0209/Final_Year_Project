using JuMP
using Gurobi
using MathOptInterface
const MOI = MathOptInterface
using Plots
using XLSX, DataFrames, Dates, Statistics, FileIO

###############################################################################
# 1. Load Electricity Prices from NREL CAMBIUM Dataset (Hourly Data)
###############################################################################
#load the data from 2050
file_path = "../data/CAISO_MC_2050.xlsx"
df = DataFrame(XLSX.readtable(file_path, 1))  # Reads first sheet
df = select(df, 1:4)
# df = df[1:10, :]


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
    2 => 1:4,
    3 => 1:2,
    4 => 1:2,
    5 => 1:10
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

push!(incoming_connections[(3, 2)], 2)  # CLINKER -> PPC
push!(incoming_connections[(3, 2)], 3)
push!(incoming_connections[(3, 2)], 4)

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
    d[(E_max, n, p, t)] = 1200000.0 / (2 * num_hours * 10)
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
alpha[(3, 2, 3)] = 0.074
alpha[(3, 2, 4)] = 0.270

# --- Production Costs ---
# assume that non-electricity costs are 60% of market price [350 rupee per 50kg bag] -> 80USD/t
combinations = [(e, n, t) for e in E for n in N[e] for t in Tset]
c = Dict(comb => 0.0 for comb in combinations)
for t in Tset
    c[(1, 1, t)] = 7.99
    c[(1, 2, t)] = 6.89
    c[(1, 3, t)] = 9.18
    c[(1, 4, t)] = 28.69
    c[(1, 5, t)] = 61.6
    c[(2, 1, t)] = 8.0 #48/6 processes
    c[(2, 2, t)] = 8.0
    c[(2, 3, t)] = 8.0
    c[(2, 4, t)] = 8.0
    c[(3, 1, t)] = 8.0
    c[(3, 2, t)] = 8.0
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
for i in N[5]
    h[(5, i)] = 10 / num_hours #assumed
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
            s[(1, n, m, t)] = 4.49 #$/tonne
        end
    end
end
#E3->E4
for n in N[3]
    for m in N[4]
        for t in Tset
            s[(3, n, m, t)] = 4.49 #$/tonne
        end
    end
end
#E4->E5
for n in N[4]
    for m in N[5]
        for t in Tset
            s[(4, n, m, t)] = 2.25 #$/tonne (half of warehouse to wholesaler)
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
combo_producing = [(e, n) for e in 1:K for n in N[e]]
capacity_cost_prod = Dict(comb => 300.0 for comb in combo_producing)
capacity_cost_storage = Dict{Tuple{Int,Int},Float64}()
# bulk silo for manufacturing
for e in 1:K, n in N[e]
    capacity_cost_storage[(e, n)] = 3
end
# bagged for downstream
for e in K+1:E_max, n in N[e]
    capacity_cost_storage[(e, n)] = 10
end

function run_scenario(tag::String)
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
    @variable(model, cap_prod[e in 2:K, n in N[e]] >= 0)
    @variable(model, cap_store[e in E, n in N[e]] >= 0)

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
        + # 6) capacity investments
        sum(capacity_cost_prod[(e, n)] * cap_prod[e, n] for e in 2:K, n in N[e])
        + sum(capacity_cost_storage[(e, n)] * cap_store[e, n] for e in 1:E_max, n in N[e]))

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
    ramp_up = Dict((e, n) => 5.0 for e in 2:3 for n in N[e])
    ramp_down = Dict((e, n) => 5.0 for e in 2:3 for n in N[e])

    for e in 2:3, n in N[e], t in 2:num_hours
        @constraint(model, x[e, n, t] - x[e, n, t-1] <= ramp_up[(e, n)])
        @constraint(model, x[e, n, t-1] - x[e, n, t] <= ramp_down[(e, n)])
    end

    # (D) On Off Decisions
    for e in 2:K, n in N[e], t in Tset
        @constraint(model, x[e, n, t] <= cap_prod[(e, n)] * y[e, n, t])
    end
    for e in 2:K, n in N[e], t in 2:num_hours
        @constraint(model, z[e, n, t] >= y[e, n, t] - y[e, n, t-1])
    end

    # (E) Capacity Constraints
    for e in 1:K, n in N[e], t in Tset
        @constraint(model, I[e, n, t] <= cap_store[e, n])
    end

    for e in K+1:E_max, n in N[e], p in P, t in Tset
        @constraint(model, J[e, n, p, t] <= cap_store[e, n])
    end

    # (F) Zero Initial Inventory
    for e in 1:K, n in N[e]
        @constraint(model, I[e, n, 0] == 0)
    end
    # downstream echelons:
    for e in K+1:E_max, n in N[e], p in P
        @constraint(model, J[e, n, p, 0] == 0)
    end

    optimize!(model)

    # ----EXPORT----
    println("here1")
    energy_over_time = [
        sum(
            elec_usage[(e, n)] * value(x[e, n, t]) / 1000
            for e in 1:3
            for n in N[e]
        )
        for t in Tset
    ]


    production_3_1 = [value(x[3, 1, t]) for t in Tset]
    production_2_2 = [value(x[2, 2, t]) for t in Tset]

    inventory_3_1 = [value(I[3, 1, t]) for t in Tset]
    inventory_2_2 = [value(I[2, 2, t]) for t in Tset]

    inventory_4_opc = [value(J[4, 1, 1, t]) for t in Tset]
    inventory_4_ppc = [value(J[4, 1, 2, t]) for t in Tset]


    println("here2")
    outflow_2_2 = [sum(value(f_up[2, 2, m, t])
                       for m in outgoing_connections[(2, 2)])
                   for t in Tset]

    outflow_4_opc = [sum(value(f_down[3, 1, m, 1, t])
                         for m in outgoing_connections[(3, 1)])
                     for t in Tset]

    production_cost = objective_value(model)

    # ---- Shipments into final stage node (5,1), split by product ----
    parents_5_1 = incoming_connections[(5, 1)]
    shipments_5_1_opc = [sum(value(f_down[4, m, 1, 1, t]) for m in parents_5_1)
                         for t in Tset]
    shipments_5_1_ppc = [sum(value(f_down[4, m, 1, 2, t]) for m in parents_5_1)
                         for t in Tset]

    # ---- Inventory at final stage node (5,1), split by product ----
    inventory_5_1_opc = [value(J[5, 1, 1, t]) for t in Tset]
    inventory_5_1_ppc = [value(J[5, 1, 2, t]) for t in Tset]



    println("\n=== Optimal cap_prod[e,n] (production capacity) ===")
    for e in 2:K, n in N[e]
        println("cap_prod[$e,$n] = ", value(cap_prod[e, n]))
    end

    println("\n=== Optimal cap_store[e,n] (storage capacity) ===")
    for e in E, n in N[e]
        println("cap_store[$e,$n] = ", value(cap_store[e, n]))
    end

    # compute *average* turnover rates over the whole horizon
    avg_turn_2_2 = sum(outflow_2_2) / mean(inventory_2_2)
    avg_turn_4_opc = sum(outflow_4_opc) / mean(inventory_4_opc)

    # repeat those scalars into two constant series
    turnover_2_2 = fill(avg_turn_2_2, num_hours)
    turnover_4_opc = fill(avg_turn_4_opc, num_hours)



    # build a DataFrame with *all* series + the two turnover columns
    df = DataFrame(
        Time_Period=Tset,
        Energy_Consumption_MWh=energy_over_time,
        Production_3_1_tonnes=production_3_1,
        Production_2_2_tonnes=production_2_2,
        Inventory_3_1=inventory_3_1,
        Inventory_2_2=inventory_2_2,
        Inventory_4_OPC=inventory_4_opc,
        Inventory_4_PPC=inventory_4_ppc,
        Outflow_2_2=outflow_2_2,
        Outflow_4_OPC=outflow_4_opc,
        Inv_Turnover_2_2=turnover_2_2,
        Inv_Turnover_4_OPC=turnover_4_opc,
        Production_Cost=production_cost,
        Shipments_5_1_OPC=shipments_5_1_opc,
        Shipments_5_1_PPC=shipments_5_1_ppc,
        Inventory_5_1_OPC=inventory_5_1_opc,
        Inventory_5_1_PPC=inventory_5_1_ppc
    )

    mkpath("capex_problem/results")
    out_file = "capex_problem/results/prod_energy_cons_$(tag).xlsx"
    XLSX.writetable(out_file, Tables.columntable(df); sheetname="Series")
    println("✓ Scenario $(tag) saved → $(out_file)")
end

run_scenario("2050_full")