using Test, JuMP
include("../src/model.jl")

@testset "Linear Optimization Model" begin
    model = define_model()
    optimize!(model)

    @test termination_status(model) == MOI.OPTIMAL
    @test isapprox(value(model[:x]), 2.0, atol=1e-6)
    @test isapprox(value(model[:y]), 2.0, atol=1e-6)
    @test isapprox(objective_value(model), 16.0, atol=1e-6)
end