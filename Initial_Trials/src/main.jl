using Gurobi, JuMP

L = 2
T = 3

# Demand
d = Dict((i, t) => 0.0 for i = 1:L, t = 1:T)
d[(1, 1)] = 10.0
d[(1, 2)] = 15.0
d[(1, 3)] = 12.0
d[(2, 1)] = 5.0
d[(2, 2)] = 20.0
d[(2, 3)] = 30.0

# Now make c(i,t)
c = Dict((i, t) => 0.0 for i in 1:L, t in 1:T)
c[(1, 1)] = 2.0
c[(1, 2)] = 4.0   # Echelon 1 cost changes from 2 -> 4
c[(1, 3)] = 20.0
c[(2, 1)] = 16.0
c[(2, 2)] = 18.0  # Echelon 2 cost changes from 16 -> 18
c[(2, 3)] = 20.0

# Holding cost (still echelon-based, if you like)
h = [0.5, 1.0]

# Capacity
C = 50.0

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

