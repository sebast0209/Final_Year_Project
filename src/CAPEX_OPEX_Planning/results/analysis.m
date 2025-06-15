%----------CAPEX-OPEX Planning Problem-------------------------------------
clear;
clc;

filenames = {
    "capex_opex_2050a.xlsx",
    %"capex_opex_2025a.xlsx"
};

for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf("\n===== Processing %s =====\n", fname);
    
    % 1) Read the entire sheet into a table
    T = readtable(fname);
    
    % 2) Print OPEX+CAPEX Cost (stored in Production_Cost column)
    if ismember("Production_Cost", T.Properties.VariableNames)
        opexCapex = T.Production_Cost(1);
        fprintf("  OPEX+CAPEX Cost = %g\n", opexCapex);
    else
        error("Column 'Production_Cost' not found in %s", fname);
    end
    
    % 3) Print Energy Cost
    if ismember("Energy_Cost", T.Properties.VariableNames)
        energyCost = T.Energy_Cost(1);
        fprintf("  Energy_Cost      = %g\n", energyCost);
    else
        warning("Column 'Energy_Cost' not found in %s", fname);
    end
    
    % 4) Print Production Cost
    if ismember("Prod_Cost", T.Properties.VariableNames)
        prodCost = sum(T.Prod_Cost);
        energyCost = T.Energy_Cost(1);
        fprintf("  Prod_Cost        = %g\n", prodCost+energyCost);
    else
        warning("Column 'Prod_Cost' not found in %s", fname);
    end
    
    % 5) Print OPEX Cost
    if ismember("OPEX_Cost", T.Properties.VariableNames)
        opexCost = T.OPEX_Cost(1);
        fprintf("  OPEX_Cost        = %g\n", opexCost);
    else
        warning("Column 'OPEX_Cost' not found in %s", fname);
    end
end

%%
    
% 1) Read the entire sheet into a table
T = readtable("capex_opex_2050a.xlsx");

% 2) Compute and print average production for echelon 2 nodes
for n = 1:4
    colName = sprintf("Production_2_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgProd = mean(T.(colName));
        maxProd = max(T.(colName));
        fprintf("  Max Production at node 2_%d = %.2f tonnes/hour\n", n, maxProd);
        fprintf("  Avg Production at node 2_%d = %.2f tonnes/hour\n", n, avgProd);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% 3) Compute and print average production for echelon 3 nodes
for n = 1:2
    colName = sprintf("Production_3_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgProd = mean(T.(colName));
        maxProd = max(T.(colName));
        fprintf("  Avg Production at node 3_%d = %.2f tonnes/hour\n", n, avgProd);
        fprintf("  Max Production at node 3_%d = %.2f tonnes/hour\n", n, maxProd);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

for n = 1:4
    colName = sprintf("Outflow_2_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgOut = mean(T.(colName));
        fprintf("  Avg Outflow at node 2_%d = %.2f tonnes/hour\n", n, avgOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow, echelon 3
for n = 1:2
    colName = sprintf("Outflow_3_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgOut = mean(T.(colName));
        fprintf("  Avg Outflow at node 3_%d = %.2f tonnes/hour\n", n, avgOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow at node (4,2)
if ismember("Outflow_4_2_tonnes", T.Properties.VariableNames)
    avgOut42 = mean(T.Outflow_4_2_tonnes);
    fprintf("  Avg Outflow at node 4_2 = %.2f tonnes/hour\n", avgOut42);
else
    warning("Column 'Outflow_4_2_tonnes' not found in %s", fname);
end

% Outflow at node (5,5)
if ismember("Outflow_5_5_tonnes", T.Properties.VariableNames)
    avgOut55 = mean(T.Outflow_5_5_tonnes);
    fprintf("  Avg Outflow at node 5_5 = %.2f tonnes/hour\n", avgOut55);
else
    warning("Column 'Outflow_5_5_tonnes' not found in %s", fname);
end

for n = 1:4
    colName = sprintf("Outflow_2_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        maxOut = max(T.(colName));
        fprintf("  Max Outflow at node 2_%d = %.2f tonnes/hour\n", n, maxOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow, echelon 3
for n = 1:2
    colName = sprintf("Outflow_3_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        maxOut = max(T.(colName));
        fprintf("  Max Outflow at node 3_%d = %.2f tonnes/hour\n", n, maxOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow at node (4,2)
if ismember("Outflow_4_2_tonnes", T.Properties.VariableNames)
    maxOut42 = max(T.Outflow_4_2_tonnes);
    fprintf("  Max Outflow at node 4_2 = %.2f tonnes/hour\n", maxOut42);
else
    warning("Column 'Outflow_4_2_tonnes' not found in %s", fname);
end

% Outflow at node (5,5)
if ismember("Outflow_5_5_tonnes", T.Properties.VariableNames)
    maxOut55 = max(T.Outflow_5_5_tonnes);
    fprintf("  Max Outflow at node 5_5 = %.2f tonnes/hour\n", maxOut55);
else
    warning("Column 'Outflow_5_5_tonnes' not found in %s", fname);
end

T = readtable("capex_opex_2025a.xlsx");

% 2) Compute and print average production for echelon 2 nodes
for n = 1:4
    colName = sprintf("Production_2_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgProd = mean(T.(colName));
        maxProd = max(T.(colName));
        fprintf("  Max Production at node 2_%d = %.2f tonnes/hour\n", n, maxProd);
        fprintf("  Avg Production at node 2_%d = %.2f tonnes/hour\n", n, avgProd);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% 3) Compute and print average production for echelon 3 nodes
for n = 1:2
    colName = sprintf("Production_3_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgProd = mean(T.(colName));
        maxProd = max(T.(colName));
        fprintf("  Avg Production at node 3_%d = %.2f tonnes/hour\n", n, avgProd);
        fprintf("  Max Production at node 3_%d = %.2f tonnes/hour\n", n, maxProd);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

for n = 1:4
    colName = sprintf("Outflow_2_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgOut = mean(T.(colName));
        fprintf("  Avg Outflow at node 2_%d = %.2f tonnes/hour\n", n, avgOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow, echelon 3
for n = 1:2
    colName = sprintf("Outflow_3_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        avgOut = mean(T.(colName));
        fprintf("  Avg Outflow at node 3_%d = %.2f tonnes/hour\n", n, avgOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow at node (4,2)
if ismember("Outflow_4_2_tonnes", T.Properties.VariableNames)
    avgOut42 = mean(T.Outflow_4_2_tonnes);
    fprintf("  Avg Outflow at node 4_2 = %.2f tonnes/hour\n", avgOut42);
else
    warning("Column 'Outflow_4_2_tonnes' not found in %s", fname);
end

% Outflow at node (5,5)
if ismember("Outflow_5_5_tonnes", T.Properties.VariableNames)
    avgOut55 = mean(T.Outflow_5_5_tonnes);
    fprintf("  Avg Outflow at node 5_5 = %.2f tonnes/hour\n", avgOut55);
else
    warning("Column 'Outflow_5_5_tonnes' not found in %s", fname);
end

for n = 1:4
    colName = sprintf("Outflow_2_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        maxOut = max(T.(colName));
        fprintf("  Max Outflow at node 2_%d = %.2f tonnes/hour\n", n, maxOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow, echelon 3
for n = 1:2
    colName = sprintf("Outflow_3_%d_tonnes", n);
    if ismember(colName, T.Properties.VariableNames)
        maxOut = max(T.(colName));
        fprintf("  Max Outflow at node 3_%d = %.2f tonnes/hour\n", n, maxOut);
    else
        warning("Column '%s' not found in %s", colName, fname);
    end
end

% Outflow at node (4,2)
if ismember("Outflow_4_2_tonnes", T.Properties.VariableNames)
    maxOut42 = max(T.Outflow_4_2_tonnes);
    fprintf("  Max Outflow at node 4_2 = %.2f tonnes/hour\n", maxOut42);
else
    warning("Column 'Outflow_4_2_tonnes' not found in %s", fname);
end

% Outflow at node (5,5)
if ismember("Outflow_5_5_tonnes", T.Properties.VariableNames)
    maxOut55 = max(T.Outflow_5_5_tonnes);
    fprintf("  Max Outflow at node 5_5 = %.2f tonnes/hour\n", maxOut55);
else
    warning("Column 'Outflow_5_5_tonnes' not found in %s", fname);
end
%%

clear;
clc;

filenames = {
    "capex_opex_2050a.xlsx",
    %"capex_opex_2025a.xlsx"
};

% List all the cap_prod and cap_store column names to extract:
capCols = { ...
    'cap_prod_2_1',  'cap_prod_2_2',  'cap_prod_2_3',  'cap_prod_2_4', ...
    'cap_prod_3_1',  'cap_prod_3_2',                      ...
    'cap_store_1_1', 'cap_store_1_2', 'cap_store_1_3', 'cap_store_1_4', 'cap_store_1_5', ...
    'cap_store_2_1', 'cap_store_2_2', 'cap_store_2_3', 'cap_store_2_4', ...
    'cap_store_3_1', 'cap_store_3_2',                      ...
    'cap_store_4_1', 'cap_store_4_2', 'cap_store_4_3', 'cap_store_4_4', 'cap_store_4_5', ...
    'cap_store_5_1', 'cap_store_5_5'                     ...
};

for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf('\n===== Processing %s =====\n', fname);

    % 1) Read the entire sheet into a table
    T = readtable(fname);

    % 2) Loop over each capacity column name, extract its (constant) value and print
    for j = 1:numel(capCols)
        colName = capCols{j};
        if ismember(colName, T.Properties.VariableNames)
            val = T.(colName)(1);  % take the first row (all entries are identical)
            fprintf('  %s = %g\n', colName, val);
        else
            warning('Column "%s" not found in %s\n', colName, fname);
        end
    end
end
%%

clear;
clc;

figPos = [100, 100, 400, 200];

filenames = {
    "capex_opex_2050a.xlsx",
    %"capex_opex_2025a.xlsx"
};

% List all the turnover‐related column names you added in Julia:
turnoverCols = { ...
    "Inventory_Turnover_AVG_1", ...
    "Inventory_Turnover_AVG_2", ...
    "Inventory_Turnover_AVG_3", ...
    "Inventory_Turnover_AVG_4", ...
    "Inventory_Turnover_AVG_5", ...
    "Inventory_Turnover_overall", ...
};

for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf("\n===== Processing %s =====\n", fname);
    
    % 1) Read the entire sheet into a table
    T = readtable(fname);
    
    % 2) For each turnover column, extract its (constant) value and print
    nTurn = numel(turnoverCols);
    turnoverVals = nan(1, nTurn);
    for j = 1:nTurn
        colName = turnoverCols{j};
        if ismember(colName, T.Properties.VariableNames)
            % Take the first row (all entries are identical)
            turnoverVals(j) = T.(colName)(1);
            fprintf("  %s = %g\n", colName, turnoverVals(j));
        else
            warning("Column “%s” not found in %s", colName, fname);
        end
    end
    
    % 3) Extract Production_Cost (also constant) and print
    if ismember("Production_Cost", T.Properties.VariableNames)
        prodCost = T.Production_Cost(1);
        fprintf("  Total Supply Chain Cost = %g\n", prodCost);
    else
        error("Column “Production_Cost” not found in %s", fname);
    end

    % 4) Extract the five Inventory_Turnover columns
    y1 = T.Inventory_Turnover_1;
    y2 = T.Inventory_Turnover_2;
    y3 = T.Inventory_Turnover_3;
    y4 = T.Inventory_Turnover_4;
    y5 = T.Inventory_Turnover_5;
    t = T.Time_Period;
    
    % 5) Plot all five on one figure
    figure('Name','Inventory Turnover by Echelon','NumberTitle','off', 'Position', figPos);
    plot(t, y1, 'LineWidth', 1.2); hold on;
    plot(t, y2, 'LineWidth', 1.2);
    plot(t, y3, 'LineWidth', 1.2);
    plot(t, y4, 'LineWidth', 1.2);
    plot(t, y5, 'LineWidth', 1.2);
    hold off;
    
    % 6) Labeling and legend
    xlabel('Time Period (hour)');
    ylabel('Inventory Turnover (turns/day)');
    title('Inventory Turnover Series for Echelons 1–5');
    legend('Echelon 1','Echelon 2','Echelon 3','Echelon 4','Echelon 5', ...
           'Location','northeast');
    grid on;
end

%%
% Script to plot key time‐series from a Julia‐generated Excel file
% using a uniform line style and color for all graphs.

clear;
clc;

filenames = {
    "capex_opex_2050a.xlsx",
    %"capex_opex_2025a.xlsx"
};

figPos = [100, 100, 400, 200];  % wider than tall


for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf("\n===== Plotting series in %s =====\n", fname);
    
    % 1) Read the entire sheet into a table
    T = readtable(fname);
    
    % 2) Extract Time_Period (x‐axis)
    t = T.Time_Period;  % assumed numeric vector of length 8760 (hours)
    
    % 3) Extract each series
    energy       = T.Energy_Consumption_MWh;
    prod31       = T.Production_3_1_tonnes;
    prod22       = T.Production_2_2_tonnes;
    inv31        = T.Inventory_3_1;
    inv22        = T.Inventory_2_2;
    inv43_opc    = T.Inventory_4_3_OPC;
    inv43_ppc    = T.Inventory_4_3_PPC;
    inv51_opc    = T.Inventory_5_1_OPC;
    inv51_ppc    = T.Inventory_5_1_PPC;
    
    % Uniform line specification:
    lineSpec = 'b-';  % blue solid line
    lw = 1.5;         % line width

    % 4) Plot Energy_Consumption_MWh vs Time_Period
    figure('Name', sprintf('Energy Consumption (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, energy, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Energy Consumption (MWh)');
    title(sprintf('Energy Consumption vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 5) Plot Production_3_1_tonnes vs Time_Period
    figure('Name', sprintf('Production 3-1 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod31, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 3-1 (tonnes/hour)');
    title(sprintf('Production at Node 3-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 6) Plot Production_2_2_tonnes vs Time_Period
    figure('Name', sprintf('Production 2-2 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod22, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 2-2 (tonnes/hour)');
    title(sprintf('Production at Node 2-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 7) Plot Inventory_3_1 vs Time_Period
    figure('Name', sprintf('Inventory 3-1 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv31, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 3-1 (tonnes)');
    title(sprintf('Inventory at Node 3-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 8) Plot Inventory_2_2 vs Time_Period
    figure('Name', sprintf('Inventory 2-2 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv22, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 2-2 (tonnes)');
    title(sprintf('Inventory at Node 2-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 9) Plot Inventory_4_3_OPC vs Time_Period
    figure('Name', sprintf('Inventory 4-3 OPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv43_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 4-3 OPC (tonnes)');
    title(sprintf('Inventory at Node 4-3 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 10) Plot Inventory_4_3_PPC vs Time_Period
    figure('Name', sprintf('Inventory 4-3 PPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv43_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 4-3 PPC (tonnes)');
    title(sprintf('Inventory at Node 4-3 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 11) Plot Inventory_5_1_OPC vs Time_Period
    figure('Name', sprintf('Inventory 5-1 OPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv51_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 5-1 OPC (tonnes)');
    title(sprintf('Inventory at Node 5-1 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 12) Plot Inventory_5_1_PPC vs Time_Period
    figure('Name', sprintf('Inventory 5-1 PPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv51_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 5-1 PPC (tonnes)');
    title(sprintf('Inventory at Node 5-1 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    

end

%%
clear;
clc;

filenames = {
    "capex_opex_2050a.xlsx",
    "capex_opex_2025a.xlsx"
};

% Define how many echelons you have energy data for:
numEchelons = 3;

for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf("\n===== Processing %s =====\n", fname);
    
    % 1) Read data
    T = readtable(fname);
    
    % 2) Sum productions (tonnes) over the horizon
    p21 = sum(T.Production_2_1_tonnes);
    p22 = sum(T.Production_2_2_tonnes);
    p31 = sum(T.Production_3_1_tonnes);
    p32 = sum(T.Production_3_2_tonnes);
    
    % 3) Compute energy for echelon 2
    %    usage factors: 2_1 → 1.77 kWh/t, 2_2 (and 2_3,2_4) use 56.7 kWh/t
    energy2 = p21 * 1.77 + (p22) * 56.7;
    
    % 4) Compute energy for echelon 3
    %    usage factors: 3_1 → 39.9 kWh/t, 3_2 → 30.6 kWh/t
    energy3 = p31 * 39.9 + p32 * 30.6;
    
    % 5) Print results
    fprintf("Total production (2_1) = %.2f t, energy = %.2f kWh\n", p21, p21*1.77);
    fprintf("Total production (2_2) = %.2f t, energy = %.2f kWh\n", p22, (p22)*56.7);
    fprintf("Echelon 2 total energy = %.2f kWh\n", energy2);
    
    fprintf("Total production (3_1) = %.2f t, energy = %.2f kWh\n", p31, p31*39.9);
    fprintf("Total production (3_2) = %.2f t, energy = %.2f kWh\n", p32, p32*30.6);
    fprintf("Echelon 3 total energy = %.2f kWh\n", energy3);
end