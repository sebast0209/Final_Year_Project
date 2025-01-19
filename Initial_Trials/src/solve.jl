using JuMP
module SolveFile

using JuMP

export solve_model, extract_solution

"""
    solve_model(model::Model)

Optimizes the given JuMP model using `optimize!(model)`.
Returns nothing, but the model stores the solved solution internally.
"""
function solve_model(model::Model)
    optimize!(model)
end

"""
    extract_solution(model, x_symbol, I_symbol)

Extracts and prints (or returns) the solution for decision variables x, I.
You can adjust to your liking. 
"""
function extract_solution(model::Model, x_var_name::Symbol, I_var_name::Symbol)
    # Extract variables by filtering their names
    x_vars = filter(v -> startswith(name(v), string(x_var_name)), all_variables(model))
    I_vars = filter(v -> startswith(name(v), string(I_var_name)), all_variables(model))

    if isempty(x_vars) || isempty(I_vars)
        @warn "Could not find variables $x_var_name or $I_var_name in the model."
        return
    end

    println("\n--- Optimal Solution ---")
    println("Objective value: ", objective_value(model))

    # Extract and print production schedule
    println("\nProduction Plan (x):")
    for v in x_vars
        println(name(v), " = ", value(v))
    end

    # Extract and print inventory schedule
    println("\nInventory Plan (I):")
    for v in I_vars
        println(name(v), " = ", value(v))
    end
end

end # module SolveFile
