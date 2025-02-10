using Gurobi, JuMP, Plots

L = 2
T = 4

# Demand
d = Dict((i, t) => 0.0 for i = 1:L, t = 1:T)
d[(1, 1)] = 5.0
d[(1, 2)] = 5.0
d[(1, 3)] = 5.0
d[(1, 4)] = 5.0
d[(2, 1)] = 30.0
d[(2, 2)] = 30.0
d[(2, 3)] = 30.0
d[(2, 4)] = 30.0

# Now make c(i,t)
c = Dict((i, t) => 0.0 for i in 1:L, t in 1:T)
c[(1, 1)] = 2.0
c[(1, 2)] = 4.0   # Echelon 1 cost changes from 2 -> 4
c[(1, 3)] = 1.0
c[(1, 4)] = 50.0
c[(2, 1)] = 15.0
c[(2, 2)] = 18.0  # Echelon 2 cost changes from 16 -> 18
c[(2, 3)] = 50.0
c[(2, 4)] = 100.0

# Holding cost (still echelon-based)
h = [0.5, 4.0]

# Capacity
C = 60.0

model = Model(Gurobi.Optimizer)

@variable(model, x[i in 1:L, t in 1:T] >= 0, base_name = "Prod")
@variable(model, I[i in 1:L, t in 0:T] >= 0, base_name = "Inv")

@objective(model, Min,
    sum(c[(i, t)] * x[i, t] + h[i] * I[i, t] for i in 1:L, t in 1:T)
)

# Initial Inv = 0, Final Inv = 0
@constraint(model, [i in 1:L], I[i, 0] == 0)
@constraint(model, [i in 1:L], I[i, T] == 0)

# Flow balance for echelon 1 (since L=2, the "intermediate" echelons are i=1)
@constraint(model, [t in 1:T],
    I[1, t-1] + x[1, t] == I[1, t] + x[2, t] + d[(1, t)]
)

# Flow balance for echelon 2 (the last echelon)
@constraint(model, [t in 1:T],
    I[2, t-1] + x[2, t] == I[2, t] + d[(2, t)]
)

# Capacity
@constraint(model, [i in 1:L, t in 1:T],
    x[i, t] <= C
)

optimize!(model)

println("\nObjective Value: ", objective_value(model))

println("\nProduction Plan (x):")
for i in 1:L, t in 1:T
    println("x[$i,$t] = ", value(x[i, t]))
end

println("\nInventory Plan (I):")
for i in 1:L, t in 0:T
    println("I[$i,$t] = ", value(I[i, t]))
end

# Plots
line_width = 3  # Increase line thickness
font_size = 20  # Set font size to double the current size

# demand for echelon 1
t_values = 1:T
y_values = [d[(1, t)] for t in t_values]
plot(t_values, y_values,
    marker=:circle,
    xlabel="t", ylabel="Demand",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/demand_1.svg")

# demand for echelon 2
y_values_2 = [d[(2, t)] for t in t_values]
plot(t_values, y_values_2,
    marker=:circle,
    xlabel="t", ylabel="Demand",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/demand_2.svg")

# cost values echelon 1
c_values = [c[(1, t)] for t in t_values]
plot(t_values, c_values,
    marker=:circle,
    xlabel="t", ylabel="Man. Cost",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/cost_1.svg")

# cost values echelon 2
c_values = [c[(2, t)] for t in t_values]
plot(t_values, c_values,
    marker=:circle,
    xlabel="t", ylabel="Order Cost",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/cost_2.svg")

# manufacture plan
x_values = [value(x[1, t]) for t in t_values]
plot(t_values, x_values,
    marker=:circle,
    xlabel="t", ylabel="Production Quantity",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/prod_1.svg")

x_values = [value(x[2, t]) for t in t_values]
plot(t_values, x_values,
    marker=:circle,
    xlabel="t", ylabel="Order Quantity",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/prod_2.svg")

# storage plan
I_values = [value(I[1, t]) for t in t_values]
plot(t_values, I_values,
    marker=:circle,
    xlabel="t", ylabel="Storage quantity",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/inventory_1.svg")

I_values = [value(I[2, t]) for t in t_values]
plot(t_values, I_values,
    marker=:circle,
    xlabel="t", ylabel="Storage quantity",
    linewidth=line_width,
    guidefont=font(font_size),
    tickfont=font(font_size),
    legendfont=font(font_size))
savefig("src/img/inventory_2.svg")