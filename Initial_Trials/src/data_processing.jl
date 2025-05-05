using XLSX
using DataFrames
using Statistics
using Plots
using FileIO

# Define columns to plot
columns_to_plot = [
    "curt_wind_MWh", "curt_solar_MWh", "curtailment_MWh", "generation",
    "variable_generation", "battery_MWh", "biomass_MWh", "beccs_MWh",
    "canada_MWh", "coal_MWh", "coal-ccs_MWh", "csp_MWh", "distpv_MWh",
    "gas-cc_MWh", "gas-cc-ccs_MWh", "gas-ct_MWh", "geothermal_MWh",
    "hydro_MWh", "nuclear_MWh", "o-g-s_MWh", "phs_MWh", "h2-ct_MWh",
    "upv_MWh", "wind-ons_MWh", "wind-ofs_MWh"
]

# Helper function to ensure folder exists
function ensure_folder(folder::String)
    if !isdir(folder)
        mkpath(folder)
    end
end

# Function to save combined plots for generation and battery
function save_combined_plot(df::DataFrame, output_folder::String)
    ensure_folder(output_folder)  # Ensure folder exists

    # Create an integer index for the x-axis
    x_index = 1:nrow(df)

    # Define custom month labels
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    xticks_positions = [730 * (i - 1) + 1 for i in 1:12]
    xticks = (xticks_positions, months)

    # Compute dynamic y-limit based on maximum values
    max_val = maximum([maximum(df[!, "variable_generation"]), maximum(df[!, "generation"]), maximum(df[!, "battery_MWh"])])
    y_limit = (0, max_val * 1.1)  # 10% margin

    # Create the combined plot
    p = plot(x_index, df[!, "variable_generation"], seriestype=:line, label="Variable Generation",
        xlabel="Month", ylabel="MWh", title="Generation and Battery Comparison",
        xticks=xticks, size=(1200, 600), xlims=(1, nrow(df)), ylims=y_limit)

    plot!(p, x_index, df[!, "generation"], seriestype=:line, label="Total Generation")
    plot!(p, x_index, df[!, "battery_MWh"], seriestype=:line, label="Battery MWh")

    # Save the plot
    savefig(p, joinpath(output_folder, "combined_generation_battery.png"))
end

function load_data(file_path::String)::DataFrame
    df = DataFrame(XLSX.readtable(file_path, 1))

    # Rename the first two columns for consistency
    rename!(df, Dict(names(df)[1] => "timestamp", names(df)[2] => "total_cost_enduse"))

    return df
end


# Helper function to load and process data
function load_and_process(file_path::String)::DataFrame
    df = DataFrame(XLSX.readtable(file_path, 1))

    # Rename the first two columns for consistency
    rename!(df, Dict(names(df)[1] => "timestamp", names(df)[2] => "total_cost_enduse"))

    # Convert cost to $/MWh
    df.total_cost_enduse ./= 1000

    # Print basic stats
    mean_price = mean(df.total_cost_enduse)
    standard_dev = std(df.total_cost_enduse)
    println("File: $file_path")
    println("Mean Electricity Price: ", mean_price)
    println("Standard Deviation: ", standard_dev)

    return df
end

# Function to save individual plots for each column using integer index for x-axis
function save_column_plot(df::DataFrame, column::String, output_folder::String)
    ensure_folder(output_folder)  # Ensure folder exists

    # Create an integer index for the x-axis
    x_index = 1:nrow(df)

    # Define custom month labels
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    xticks_positions = [730 * (i - 1) + 1 for i in 1:12]
    xticks = (xticks_positions, months)

    # Compute dynamic y-limit based on maximum value of the column
    max_val = maximum(df[!, column])
    y_limit = (0, max_val * 1.1)  # 10% margin

    # Plot with adjusted y-limits
    p = plot(x_index, df[!, column], seriestype=:line, label=column,
        xlabel="Month", ylabel="MWh", legend=:topright, title=column,
        xticks=xticks, size=(1200, 1200), xlims=(1, nrow(df)), ylims=y_limit)

    savefig(p, joinpath(output_folder, "$(column).png"))
end

function save_pie_chart(df::DataFrame, output_folder::String)
    ensure_folder(output_folder)  # Ensure folder exists

    # Calculate yearly averages
    avg_variable_generation = mean(df[!, "variable_generation"])
    avg_generation = mean(df[!, "generation"])
    avg_battery = mean(df[!, "battery_MWh"])

    # Data for pie chart
    averages = [avg_variable_generation, avg_generation, avg_battery]
    labels = ["Variable Generation", "Total Generation", "Battery MWh"]

    # Create and save the pie chart
    p = pie(averages, labels=labels, title="Average Contribution Over the Year")
    savefig(p, joinpath(output_folder, "average_generation_battery_pie.png"))
end

# Master function to process each year
function process_year(file_path::String, year::String)
    df = load_and_process(file_path)

    # Define output folder for this year
    output_folder = joinpath("img", "data_analysis", year)
    ensure_folder(output_folder)

    # Generate and save plots for each column
    for col in columns_to_plot
        if col in names(df)
            save_column_plot(df, col, output_folder)
        else
            println("Column $col not found in $year dataset.")
        end
    end

    # Save combined plots
    save_combined_plot(df, output_folder)
    save_additional_combined_plot(df, output_folder)
    save_pie_chart(df, output_folder)
end

# Function to compute and print averages
function print_averages_and_percentages(df::DataFrame, year::String)
    # Calculate averages
    avg_variable_generation = mean(df[!, "variable_generation"])
    avg_battery = mean(df[!, "battery_MWh"])
    avg_generation = mean(df[!, "generation"])

    # Calculate non-variable generation
    avg_non_variable_generation = avg_generation - avg_variable_generation

    # Calculate percentages
    pct_variable_generation = (avg_variable_generation / avg_generation) * 100
    pct_non_variable_generation = (avg_non_variable_generation / avg_generation) * 100
    pct_battery = (avg_battery / avg_generation) * 100

    # Print results
    println("\nAverages for $year:")
    println("Average Variable Generation (MWh): ", avg_variable_generation)
    println("Average Non-Variable Generation (MWh): ", avg_non_variable_generation)
    println("Average Battery Generation (MWh): ", avg_battery)
    println("Average Total Generation (MWh): ", avg_generation)

    # Print percentages
    println("\nPercentages for $year:")
    println("Variable Generation: ", round(pct_variable_generation, digits=2), "%")
    println("Non-Variable Generation: ", round(pct_non_variable_generation, digits=2), "%")
    println("Battery Generation: ", round(pct_battery, digits=2), "%")
end

function plot_variable_generation(file_path::String; year::String="2025", use_month_labels::Bool=true, save::Bool=true)
    # Load data
    df = DataFrame(XLSX.readtable(file_path, 1))
    rename!(df, Dict(names(df)[1] => "timestamp", names(df)[2] => "total_cost_enduse"))

    # Extract variable_generation column
    y = df[!, "variable_generation"]
    x = 1:nrow(df)

    # Optional x-axis month labels
    xticks = nothing
    if use_month_labels
        xticks_positions = [730 * (i - 1) + 1 for i in 1:12]
        xtick_labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        xticks = (xticks_positions, xtick_labels)
    end

    # Create the plot
    p = plot(x, y,
        xlabel=use_month_labels ? "Month" : "Index",
        ylabel="MWh",
        title="Variable Generation Over Time",
        legend=false,
        lw=2,
        xticks=xticks,
        size=(1200, 600))

    # Save plot if needed
    if save
        folder = joinpath("img", "data_analysis", year)
        mkpath(folder)
        savefig(p, joinpath(folder, "variable_generation_timeseries.png"))
    end

    return p
end

function plot_renewable_penetration(file_path::String; year::String="2025", use_month_labels::Bool=true, save::Bool=true)
    # Load data
    df = DataFrame(XLSX.readtable(file_path, 1))
    rename!(df, Dict(names(df)[1] => "timestamp", names(df)[2] => "total_cost_enduse"))

    # Extract columns
    variable = df[!, "variable_generation"]
    total = df[!, "generation"]

    # Avoid divide-by-zero issues
    penetration = [t > 0 ? v / t : 0.0 for (v, t) in zip(variable, total)]
    x = 1:nrow(df)

    # Optional month labels
    xticks = nothing
    if use_month_labels
        xticks_positions = [730 * (i - 1) + 1 for i in 1:12]
        xtick_labels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        xticks = (xticks_positions, xtick_labels)
    end

    # Plot
    p = plot(x, penetration,
        xlabel=use_month_labels ? "Month" : "Index",
        ylabel="Renewable Penetration",
        title="Renewable Penetration Over Time",
        legend=false,
        lw=2,
        xticks=xticks,
        size=(1200, 600),
        ylim=(0, 1.05))  # Because penetration is a ratio

    # Save if needed
    if save
        folder = joinpath("img", "data_analysis", year)
        mkpath(folder)
        savefig(p, joinpath(folder, "renewable_penetration_timeseries.png"))
    end

    return p
end


# Main execution
function main()
    # process_year("../data/CAISO_MC_2025.xlsx", "2025")
    # process_year("../data/CAISO_MC_2050.xlsx", "2050")
    # println("\nAll plots have been saved in img/data_analysis/2025 and img/data_analysis/2050")

    df_2025 = load_data("../data/CAISO_MC_2025.xlsx")
    df_2050 = load_data("../data/CAISO_MC_2050.xlsx")

    # Print averages for each year
    # print_averages_and_percentages(df_2025, "2025")
    # print_averages_and_percentages(df_2050, "2050")

    # plot_variable_generation("../data/CAISO_MC_2025.xlsx", year="2025")
    plot_renewable_penetration("../data/CAISO_MC_2025.xlsx", year="2025")
end

main()
