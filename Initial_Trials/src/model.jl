module ModelFile

using JuMP
using Gurobi

export build_model

"""
    build_model(L, T, d, c, h, C)

Builds a multi-echelon lot-sizing model with:
- L echelons
- T time periods
- d[i,t] demand
- c[i] production cost per unit for echelon i
- h[i] holding cost per unit for echelon i
- C capacity (uniform in this simple example)

Returns: a JuMP.Model
"""
function build_model(L, T, d, c, h)
    # 1. Create a JuMP model
    model = Model(Gurobi.Optimizer)

    # 2. Decision variables
    # x[i,t] => production/transfer at echelon i, period t
    # I[i,t] => inventory at echelon i at end of period t
    @variable(model, x[i in 1:L, t in 1:T] >= 0, base_name = "Prod")
    @variable(model, I[i in 1:L, t in 0:T] >= 0, base_name = "Inv")

    # 3. Objective
    # Minimize sum of production + holding cost
    @objective(model, Min,
        sum(c[i] * x[i, t] + h[i] * I[i, t] for i in 1:L, t in 1:T)
    )

    # 4. Constraints

    ## 4.1 Initial Inventory = 0
    @constraint(model, [i in 1:L], I[i, 0] == 0)

    ## 4.2 Final Inventory = 0
    @constraint(model, [i in 1:L], I[i, T] == 0)

    ## 4.3 Flow balance for i in 1:(L-1)
    @constraint(model, flow_bal_intermediate[i in 1:(L-1), t in 1:T],
        I[i, t-1] + x[i, t] == I[i, t] + x[i+1, t] + d[(i, t)]
    )

    ## 4.4 Flow balance for last echelon (L)
    @constraint(model, flow_bal_last[t in 1:T],
        I[L, t-1] + x[L, t] == I[L, t] + d[(L, t)]
    )

    # ## 4.5 Capacity constraints
    # @constraint(model, capacity_con[i in 1:L, t in 1:T],
    #     x[i,t] <= C
    # )

    # Return the model and decision variables
    # Print Production Plan (x)
    println("\nProduction Plan (x):")
    for i in 1:L, t in 1:T
        println("x[$i,$t] = ", value(x[i, t]))
    end

    # Print Inventory Plan (I)
    println("\nInventory Plan (I):")
    for i in 1:L, t in 0:T
        println("I[$i,$t] = ", value(I[i, t]))
    end

    return model
end


end # module ModelFile
