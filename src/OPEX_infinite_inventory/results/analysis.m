%-------------------------OPEX Planning Problem----------------------------
%---------------------Ideal case: Infinite inventory-----------------------
%%
clear;
clc;

filenames = {
    "infinite_cap_2025a.xlsx", ...
    "infinite_Cap_2050a.xlsx"
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
    "infinite_cap_2025a.xlsx", ...
    "infinite_cap_2050a.xlsx"
};

figPos = [100, 100, 400, 200];

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
    if ismember("OPEX_Cost", T.Properties.VariableNames)
        OPEXCost = T.OPEX_Cost(1);
        fprintf("  Total Supply Chain Cost = %g\n", OPEXCost);
    else
        error("Column “OPEX_Cost” not found in %s", fname);
    end

    % 4) Extract the five Inventory_Turnover columns
    y1 = T.Inventory_Turnover_1;
    y2 = T.Inventory_Turnover_2;
    y3 = T.Inventory_Turnover_3;
    y4 = T.Inventory_Turnover_4;
    y5 = T.Inventory_Turnover_5;
    t = T.Time_Period;
    
    % 5) Plot all five on one figure
    figure('Name','Inventory Turnover by Echelon','NumberTitle','off','Position',figPos);
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
% with wider (landscape) figure dimensions.

clear;
clc;

filenames = {
    "infinite_cap_2025a.xlsx", ...
    "infinite_cap_2050a.xlsx"
};

% Desired figure size: [left, bottom, width, height]
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
    figure('Name', sprintf('Energy Consumption (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, energy, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Energy Consumption (MWh)');
    title(sprintf('Energy Consumption vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 5) Plot Production_3_1_tonnes vs Time_Period
    figure('Name', sprintf('Production 3-1 (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod31, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 3-1 (tonnes/hour)');
    title(sprintf('Production at Node 3-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 6) Plot Production_2_2_tonnes vs Time_Period
    figure('Name', sprintf('Production 2-2 (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, prod22, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Production 2-2 (tonnes/hour)');
    title(sprintf('Production at Node 2-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 7) Plot Inventory_3_1 vs Time_Period
    figure('Name', sprintf('Inventory 3-1 (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv31, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 3-1 (tonnes)');
    title(sprintf('Inventory at Node 3-1 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 8) Plot Inventory_2_2 vs Time_Period
    figure('Name', sprintf('Inventory 2-2 (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv22, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 2-2 (tonnes)');
    title(sprintf('Inventory at Node 2-2 vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 9) Plot Inventory_4_3_OPC vs Time_Period
    figure('Name', sprintf('Inventory 4-3 OPC (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv43_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 4-3 OPC (tonnes)');
    title(sprintf('Inventory at Node 4-3 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 10) Plot Inventory_4_3_PPC vs Time_Period
    figure('Name', sprintf('Inventory 4-3 PPC (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv43_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 4-3 PPC (tonnes)');
    title(sprintf('Inventory at Node 4-3 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 11) Plot Inventory_5_1_OPC vs Time_Period
    figure('Name', sprintf('Inventory 5-1 OPC (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv51_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 5-1 OPC (tonnes)');
    title(sprintf('Inventory at Node 5-1 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 12) Plot Inventory_5_1_PPC vs Time_Period
    figure('Name', sprintf('Inventory 5-1 PPC (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, inv51_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Inventory 5-1 PPC (tonnes)');
    title(sprintf('Inventory at Node 5-1 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 13) Plot Outflow_2_2_OPC vs Time_Period
    figure('Name', sprintf('Outflow 2-2 OPC (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, out22_opc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Outflow 2-2 OPC (tonnes/hour)');
    title(sprintf('Outflow from Node 2-2 (OPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
    
    % 14) Plot Outflow_2_2_PPC vs Time_Period
    figure('Name', sprintf('Outflow 2-2 PPC (%s)', fname), ...
           'NumberTitle', 'off', 'Position', figPos);
    plot(t, out22_ppc, lineSpec, 'LineWidth', lw);
    xlabel('Time Period (hour)');
    ylabel('Outflow 2-2 PPC (tonnes/hour)');
    title(sprintf('Outflow from Node 2-2 (PPC) vs. Time (%s)', fname), 'Interpreter', 'none');
    grid on;
end
%%

clear;
clc;

filenames = {
    "infinite_cap_2025.xlsx", ...
    "infinite_cap_2050.xlsx"
};

% Assuming the script already has loaded each table T for 2025 and 2050 in the loop,
% and extracted prod22 and t = T.Time_Period (which should be datetime arrays).

for i = 1:numel(filenames)
    fname = filenames{i};
    fprintf("\n===== Processing %s =====\n", fname);
    
    % Read table and extract datetime + prod22
    T = readtable(fname);
    ts = T.Time_Period;               % datetime array of length 8760
    prod22 = T.Production_2_2_tonnes; % production at node 2_2
    
    % Determine year and corresponding three‐month window
    if contains(fname, '2025')
        year_val = 2025;
        months_window = [4,5,6];         % April–June
        window_label = "Apr–Jun";
    else
        year_val = 2050;
        months_window = [3,4,5];         % March–May
        window_label = "Mar–May";
    end
    
    % Mask for the three‐month window
    mask_three = (year(ts) == year_val) & ismember(month(ts), months_window);
    
    % Sum production over the target three‐month window
    prod_three_month = sum(prod22(mask_three));
    
    % Mask for the entire year
    mask_year = (year(ts) == year_val);
    
    % Sum total production over entire year
    total_prod_year = sum(prod22(mask_year));
    
    % Compute percentage
    pct = 100 * prod_three_month / total_prod_year;
    
    % Print results
    fprintf("For %d, production (2_2) from %s = %.2f tonnes\n", ...
        year_val, window_label, prod_three_month);
    fprintf("Total production (2_2) in %d = %.2f tonnes\n", ...
        year_val, total_prod_year);
    fprintf("Percentage = %.2f%%\n\n", pct);
end
