%-------------------------OPEX Planning Problem----------------------------
%------------------------Base case: No inventory---------------------------
%clear;
%clc;

filenames = {
    "zero_inv_2025a.xlsx", ...
    "zero_inv_2050a.xlsx"
};

for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf("\n===== Processing %s =====\n", fname);
    
    % 1) Read the entire sheet into a table
    T = readtable(fname);
    
    % 2) Print OPEX+CAPEX Cost (stored in Production_Cost column)
    if ismember("OPEX_Cost", T.Properties.VariableNames)
        opexCapex = T.OPEX_Cost(1);
        fprintf("  OPEX Cost = %g\n", opexCapex);
    else
        error("Column 'OPEX_Cost' not found in %s", fname);
    end
    
    % 3) Print Energy Cost
    if ismember("Energy_Cost", T.Properties.VariableNames)
        energyCost = T.Energy_Cost(1);
        fprintf("  Energy_Cost      = %g\n", energyCost);
    else
        warning("Column 'Energy_Cost' not found in %s", fname);
    end

    % 8)Extract Production Cost
    if ismember("Production_Cost", T.Properties.VariableNames)
        energyCost = T.Energy_Cost(1);
        prodCost = sum(T.Production_Cost) + energyCost;
        fprintf("  Production_Cost = %g\n", prodCost);
    else
        error("Column “Production_Cost” not found in %s", fname);
    end
end

%%
clear;
clc;

filenames = {
    "zero_inv_2025a.xlsx", ...
    "zero_inv_2050a.xlsx"
};

% List all the turnover‐related column names you added in Julia:
turnoverCols = { ...
    "Inventory_Turnover_AVG_1", ...
    "Inventory_Turnover_AVG_2", ...
    "Inventory_Turnover_AVG_3", ...
    "Inventory_Turnover_AVG_4", ...
    "Inventory_Turnover_AVG_5", ...
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
end


%%
clear;
clc;

filenames = {
    "zero_inv_2025a.xlsx", ...
    "zero_inv_2050a.xlsx"
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
    out22_opc    = T.Outflow_2_2_OPC;
    out22_ppc    = T.Outflow_2_2_PPC;

    
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
    %title(sprintf('Production at Node 3-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 6) Plot Production_2_2_tonnes vs Time_Period
    figure('Name', sprintf('Production 2-2 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod22, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 2-2 (tonnes/hour)');
    %title(sprintf('Production at Node 2-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 7) Plot Inventory_3_1 vs Time_Period
    figure('Name', sprintf('Inventory 3-1 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv31, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 3-1 (tonnes)');
    %title(sprintf('Inventory at Node 3-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 8) Plot Inventory_2_2 vs Time_Period
    figure('Name', sprintf('Inventory 2-2 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv22, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 2-2 (tonnes)');
    %title(sprintf('Inventory at Node 2-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 9) Plot Inventory_4_3_OPC vs Time_Period
    figure('Name', sprintf('Inventory 4-3 OPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv43_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 4-3 OPC (tonnes)');
    %title(sprintf('Inventory at Node 4-3 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 10) Plot Inventory_4_3_PPC vs Time_Period
    figure('Name', sprintf('Inventory 4-3 PPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv43_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 4-3 PPC (tonnes)');
    %title(sprintf('Inventory at Node 4-3 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 11) Plot Inventory_5_1_OPC vs Time_Period
    figure('Name', sprintf('Inventory 5-1 OPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv51_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 5-1 OPC (tonnes)');
    %title(sprintf('Inventory at Node 5-1 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 12) Plot Inventory_5_1_PPC vs Time_Period
    figure('Name', sprintf('Inventory 5-1 PPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv51_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 5-1 PPC (tonnes)');
    %title(sprintf('Inventory at Node 5-1 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 13) Plot Outflow_2_2_OPC vs Time_Period
    figure('Name', sprintf('Outflow 2-2 OPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, out22_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Outflow 2-2 OPC (tonnes)');
    %title(sprintf('Outflow from Node 2-2 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 14) Plot Outflow_2_2_PPC vs Time_Period
    figure('Name', sprintf('Outflow 2-2 PPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, out22_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Outflow 2-2 PPC (tonnes)');
    %title(sprintf('Outflow from Node 2-2 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;

    % 15) Plot Inflow_5_5_PPC vs Time_Period
    figure('Name', sprintf('Inflow 5-5 OPC (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, T.Inflow_5_5_OPC, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inflow (5,5) OPC (tonnes)');
    %title(sprintf('Inflow of OPC to Node (5,5) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
end

%%

clear;
clc;

filenames = {
    "zero_inv_2050_cap_exp.xlsx"
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
    prod32       = T.Production_3_2_tonnes;
    prod21       = T.Production_2_1_tonnes;
    prod23       = T.Production_2_3_tonnes;
    prod24       = T.Production_2_4_tonnes;


    
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

    % 7) Plot Production_3_2_tonnes vs Time_Period
    figure('Name', sprintf('Production 3-2 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod32, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 3-2 (tonnes/hour)');
    title(sprintf('Production at Node 3-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 8) Plot Production_3_2_tonnes vs Time_Period
    figure('Name', sprintf('Production 2-3 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod23, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 2-3 (tonnes/hour)');
    title(sprintf('Production at Node 2-3 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;

    % 79) Plot Production_2_1_tonnes vs Time_Period
    figure('Name', sprintf('Production 2-1 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod21, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 2-1 (tonnes/hour)');
    title(sprintf('Production at Node 2-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;

    % 10) Plot Production_2-4_tonnes vs Time_Period
    figure('Name', sprintf('Production 2-4 (%s)', fname), 'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod24, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 2-4 (tonnes/hour)');
    title(sprintf('Production at Node 2-4 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
end

