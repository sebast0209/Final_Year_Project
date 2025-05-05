###############################################################################
# 0. Load Packages
###############################################################################
using JuMP
using Gurobi
using MathOptInterface
const MOI = MathOptInterface
using Plots
using XLSX, DataFrames, Dates, Statistics, FileIO

###############################################################################
# 1. Load Electricity Prices from NREL CAMBIUM Dataset
###############################################################################
save_path = "img/2025"
mkpath(save_path)  # Create directory if it doesn't exist

# Load the Excel file
file_path = "../data/CAISO_MC_2025.xlsx"
df = DataFrame(XLSX.readtable(file_path, 1))  # Reads first sheet

# Rename columns for consistency
rename!(df, [:timestamp, :total_cost_enduse])

# Extract the date part (without time)
df.date = Date.(df.timestamp)
df.total_cost_enduse ./= 1000

# Compute the daily average of total_cost_enduse
daily_avg = combine(groupby(df, :date), :total_cost_enduse => mean => :daily_avg)
elec_price = daily_avg.daily_avg
num_days = length(elec_price)
x_indices = 1:num_days
month_labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
month_positions = round.(Int, range(1, num_days, length=12))  # Equally spaced positions

mean_price = mean(elec_price)

# Plot
# Plot daily electricity prices
p = plot(x_indices, elec_price, label="Daily Avg Cost", xlabel="Month", ylabel="Total Marginal Cost End User (\$/kWh)",
    title="Daily Marginal Cost (2025)", xticks=(month_positions, month_labels), lw=2, legend=:topright)

# Plot horizontal mean line
hline!([mean_price], linestyle=:dash, color=:red, label="Mean Cost")

# Annotate mean value on the graph
annotate!(num_days * 0.8, mean_price, text("Mean: \$$(round(mean_price, digits=2))", 10, :red))
savefig(joinpath(save_path, "daily_avg_cost_2025.png"))
println("Plot saved at $(joinpath(save_path, "daily_avg_cost_2025.png"))")

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
# 3. MODEL: Build and Solve the JuMP Model
###############################################################################

model = Model(Gurobi.Optimizer)

# Decision Variables
@variable(model, x[e in E, n in N[e], t in Tset] >= 0)
@variable(model, I[e in E, n in N[e], t in 0:maximum(Tset)] >= 0)
@variable(model, J[e in E, n in N[e], m in incoming_connections[(e, n)], t in 0:maximum(Tset)] >= 0)
@variable(model, f[e in E[1:end-1], n in N[e], m in N[e+1], t in 0:maximum(Tset)] >= 0)

# Objective Function
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

# Solve the model
optimize!(model)

# Time sets
time_prod = Tset           # For production and shipping, use t = 1:6
time_inv = 0:maximum(Tset) # For inventory, note that t starts at 0

########################################################################
# a. Plot Production (x): for each echelon and each node
########################################################################
for e in E
    for n in N[e]
        # Extract production values over time
        prod = [value(x[e, n, t]) for t in time_prod]

        # Create a line plot for production
        p = plot(time_prod, prod,
            lw=2,
            label="Production",
            title="Production at Echelon $e, Node $n",
            xlabel="Time Period",
            ylabel="Production")

        # Save the plot as a PNG file in the designated folder
        savefig(p, "$(save_path)/production_e$(e)_node$(n).png")
    end
end

########################################################################
# b. Plot Inventory (I): for each echelon and each node
########################################################################
for e in E
    for n in N[e]
        # Extract inventory values over time (including period 0)
        inv = [value(I[e, n, t]) for t in time_inv]

        # Create a line plot for inventory
        p = plot(time_inv, inv,
            lw=2,
            label="Inventory",
            title="Inventory at Echelon $e, Node $n",
            xlabel="Time Period",
            ylabel="Inventory")

        # Save the plot as a PNG file
        savefig(p, "$(save_path)/inventory_e$(e)_node$(n).png")
    end
end

########################################################################
# c. Plot Shipping Flows (f): for each node in each echelon (except the last)
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
                    lw=2,
                    label="To Node $m (Echelon $(e+1))")
            end

            # Save the shipping flows plot as a PNG file
            savefig(p, "$(save_path)/shipping_e$(e)_node$(n).png")
        end
    end
end