# Reimagining Supply Chains in an Era of Increased Renewable Energy Penetration

> **Final Year Project**  
> MEng Electronic and Information Engineering, Imperial College London

This project investigates the potential of long-term Demand-Side Management (DSM) in energy-intensive industrial supply chains under increasing electricity price volatility driven by renewable energy integration. A model of a cement supply chain—including raw material extraction, intermediate processing, and distribution of two cement products (Ordinary Portland Cement and Portland Pozzolana Cement)—was first developed and formulated as a large-scale mixed-integer linear program. This optimisation framework, implemented in JuMP and solved using Gurobi, co-optimises capital investment and operational expenditure (OPEX). To extract insights, the model was applied to a real-world case study using production parameters from a cement plant in India and electricity price data from the National Renewable Energy Laboratory’s Cambium dataset.


The model captures hourly dynamics in production, storage, and logistics across a one-year horizon, enabling analysis of cost-saving opportunities through strategic load shifting and inventory control. Simulations are conducted using real-world production parameters from a cement facility in India, under scenarios with differing levels of storage and production flexibility.

## 📋 Requirements

Ensure the following Julia packages are installed:

- [`JuMP.jl`](https://jump.dev/) — Mathematical optimization modeling language  
- [`Gurobi.jl`](https://github.com/jump-dev/Gurobi.jl) — Interface to the Gurobi solver  
- [`MathOptInterface.jl`](https://github.com/jump-dev/MathOptInterface.jl) — Backend interface for optimization  
- [`Plots.jl`](https://github.com/JuliaPlots/Plots.jl) — Plotting and visualization  
- [`XLSX.jl`](https://github.com/felipenoris/XLSX.jl) — Read/write Excel files  
- [`DataFrames.jl`](https://github.com/JuliaData/DataFrames.jl) — Data manipulation  
- [`Dates`](https://docs.julialang.org/en/v1/stdlib/Dates/) — Built-in Julia date utilities  
- [`Statistics`](https://docs.julialang.org/en/v1/stdlib/Statistics/) — Basic statistical functions  
- [`FileIO.jl`](https://github.com/JuliaIO/FileIO.jl) — Unified file loading interface  

> 💡 Make sure Gurobi is installed separately and your license is activated.

---


## 🗂️ Codebase Organisation

The project repository is organised into two main directories:

- `data/`: Contains all input datasets, including time series electricity price data from the  
  [NREL Cambium dataset](https://www.nrel.gov/analysis/cambium). This project uses data specific to the CAISO region.

- `src/`: Contains all modelling scripts, grouped by experiment type. Each experiment has:
  - A Julia script to run the optimisation model
  - A `results/` subfolder where output Excel files are saved
  - A MATLAB script to analyse the results

### 🔬 Experiment Directory Structure

| Experiment | Description | Julia Script | MATLAB Analysis |
|------------|-------------|--------------|------------------|
| **OPEX Planning – Zero Inventory** | Models short-term operational expenditure without storage flexibility | [`zero_inventory.jl`](src/OPEX_zero_inventory/zero_inventory.jl) | [`analysis.m`](src/OPEX_zero_inventory/results/analysis.m) |
| **OPEX Planning – Infinite Inventory** | Allows full inventory flexibility to evaluate the upper bound of DSM value | [`infinite_inventory.jl`](src/OPEX_infinite_inventory/infinite_inventory.jl) | [`analysis.m`](src/OPEX_infinite_inventory/results/analysis.m) |
| **Capacity Experiments** | Tests the effect of varying production and storage capacity levels | [`cap_experiment.jl`](src/OPEX_capacity_experiments/cap_experiment.jl) | [`analysis.m`](src/OPEX_capacity_experiments/results/analysis.m) |
| **CAPEX-OPEX Planning** | Jointly optimises capital investment and operational cost across the supply chain | [`capex_opex.jl`](src/CAPEX_OPEX_Planning/capex_opex.jl) | [`analysis.m`](src/CAPEX_OPEX_Planning/results/analysis.m) |

> 💡 All results are written to Excel format in each experiment's `results/` folder.

---

### ⚠️ Notes on Output Files

If you wish to rerun any of the Julia experiments, you **must** update the output file path defined within each script.  
By default, output files are saved with names like `2025a.xlsx` or `2050a.xlsx`, and running a script without renaming this path may overwrite existing results.

#### Example

To run the **infinite inventory** experiment:

1. Open the file [`src/OPEX_infinite_inventory/infinite_inventory.jl`](src/OPEX_infinite_inventory/infinite_inventory.jl)  
2. Scroll to the bottom and locate the following lines:

   ```julia
   run_scenario("../data/CAISO_MC_2050.xlsx", "2050a")
   run_scenario("../data/CAISO_MC_2025.xlsx", "2025a")
