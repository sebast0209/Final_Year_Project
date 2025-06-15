clear;
clc;

%figPos = [100, 100, 400, 200];  % wider than tall

% CAISO 2050 Plot
% 1) Read the data into a table
T2050 = readtable('CAISO_MC_2050.xlsx');
figPos = [100, 100, 400, 200];

% 2) Extract timestamp and total_cost_enduse columns
ts2050 = T2050.timestamp;             
cost2050 = T2050.total_cost_enduse;   

% If timestamp is read as text, convert to datetime:
if iscell(ts2050) || ischar(ts2050)
    ts2050 = datetime(ts2050, 'InputFormat', 'yyyy-MM-dd HH:mm:ss'); 
end

% 3) Compute the mean and standard deviation
mean2050 = mean(cost2050);
std2050  = std(cost2050);

% 4) Print mean and standard deviation
fprintf('CAISO 2050:\n');
fprintf('  Mean total_cost_enduse = %.2f\n', mean2050);
fprintf('  Std  total_cost_enduse = %.2f\n\n', std2050);

% 5) Plot total_cost_enduse vs. timestamp
figure('Name','CAISO 2050 Electricity Marginal Cost','NumberTitle','off', 'Position', figPos);
plot(ts2050, cost2050, 'b-', 'LineWidth', 1.2);
%hold on;

% 6) Add horizontal line at the mean and label it
%yline(mean2050, 'r--', 'LineWidth', 1.5, 'DisplayName', sprintf('Mean = %.2f', mean2050));

%hold off;
xlabel('Timestamp');
ylabel('Total Cost End‐Use ($/MWh)');
title('CAISO MC 2050: Total Cost End‐Use vs. Time');
grid on;

%% CAISO 2025 Plot
% 1) Read the data into a table
T2025 = readtable('CAISO_MC_2025.xlsx');

% 2) Extract timestamp and total_cost_enduse columns
ts2025 = T2025.timestamp;             
cost2025 = T2025.total_cost_enduse;   

% If timestamp is read as text, convert to datetime:
if iscell(ts2025) || ischar(ts2025)
    ts2025 = datetime(ts2025, 'InputFormat', 'yyyy-MM-dd HH:mm:ss'); 
end

% 3) Compute the mean and standard deviation
mean2025 = mean(cost2025);
std2025  = std(cost2025);

% 4) Print mean and standard deviation
fprintf('CAISO 2025:\n');
fprintf('  Mean total_cost_enduse = %.2f\n', mean2025);
fprintf('  Std  total_cost_enduse = %.2f\n\n', std2025);

% 5) Plot total_cost_enduse vs. timestamp
figure('Name','CAISO 2025 Electricity Marginal Cost','NumberTitle','off', 'Position', figPos);
plot(ts2025, cost2025, 'b-', 'LineWidth', 1.2);
%hold on;

% 6) Add horizontal line at the mean and label it
%yline(mean2025, 'r--', 'LineWidth', 1.5, 'DisplayName', sprintf('Mean = %.2f', mean2025));

%hold off;
xlabel('Timestamp');
ylabel('Total Cost End‐Use ($/MWh)');
title('CAISO MC 2025: Total Cost End‐Use vs. Time');
grid on;



%%

% 1) Extract the timestamp vector
ts = T2025.timestamp;    

% 2) Compute the constant value
constVal = 15000000.0 / (8760*15*2);    

% 3) Create a vector of the same length as ts, filled with constVal
y = ones(size(ts)) * constVal;

% 4) Plot the constant line against timestamp
figure('Name','Demand for OPC at (5,1)','NumberTitle','off', 'Position', figPos);
plot(ts, y, 'b-', 'LineWidth', 1.5);
xlabel('Timestamp');
ylabel(sprintf('Demand (tonnes)', constVal));
title('Demand for OPC at (5,1) over time');
grid on;

%% For CAISO 2050: compute three‐month rolling averages
yr2050  = year(ts2050);
mo2050  = month(ts2050);
ym2050  = yr2050*100 + mo2050;
uniqueYm = unique(ym2050);

nMonths = numel(uniqueYm);
periodAvgs2050   = nan(nMonths-2, 1);
periodLabels2050 = strings(nMonths-2, 1);

for k = 1:(nMonths-2)
    windowYm = uniqueYm(k:k+2);
    mask = ismember(ym2050, windowYm);
    periodAvgs2050(k) = mean(cost2050(mask));
    
    y1 = floor(windowYm(1)/100);
    m1 = mod(windowYm(1), 100);
    y3 = floor(windowYm(3)/100);
    m3 = mod(windowYm(3), 100);
    dt1 = datetime(y1, m1, 1);
    dt3 = datetime(y3, m3, 1);
    % Use 'shortname' for three-letter month
    label1 = char(month(dt1, 'shortname'));
    label3 = char(month(dt3, 'shortname'));
    periodLabels2050(k) = sprintf("%s %d – %s %d", label1, y1, label3, y3);
end

fprintf("\nCAISO 2050: Three‐month period averages:\n");
for k = 1:numel(periodAvgs2050)
    fprintf("  %s: Mean = %.2f\n", periodLabels2050(k), periodAvgs2050(k));
end

[maxAvg2050, idxMax2050] = max(periodAvgs2050);
[minAvg2050, idxMin2050] = min(periodAvgs2050);
fprintf("\n2050 Highest 3‐month average: %s = %.2f\n", ...
    periodLabels2050(idxMax2050), maxAvg2050);
fprintf("2050 Lowest  3‐month average: %s = %.2f\n\n", ...
    periodLabels2050(idxMin2050), minAvg2050);

% For CAISO 2025: compute three‐month rolling averages
yr2025  = year(ts2025);
mo2025  = month(ts2025);
ym2025  = yr2025*100 + mo2025;
uniqueYm = unique(ym2025);

nMonths = numel(uniqueYm);
periodAvgs2025   = nan(nMonths-2, 1);
periodLabels2025 = strings(nMonths-2, 1);

for k = 1:(nMonths-2)
    windowYm = uniqueYm(k:k+2);
    mask = ismember(ym2025, windowYm);
    periodAvgs2025(k) = mean(cost2025(mask));
    
    y1 = floor(windowYm(1)/100);
    m1 = mod(windowYm(1), 100);
    y3 = floor(windowYm(3)/100);
    m3 = mod(windowYm(3), 100);
    dt1 = datetime(y1, m1, 1);
    dt3 = datetime(y3, m3, 1);
    label1 = char(month(dt1, 'shortname'));
    label3 = char(month(dt3, 'shortname'));
    periodLabels2025(k) = sprintf("%s %d – %s %d", label1, y1, label3, y3);
end

fprintf("CAISO 2025: Three‐month period averages:\n");
for k = 1:numel(periodAvgs2025)
    fprintf("  %s: Mean = %.2f\n", periodLabels2025(k), periodAvgs2025(k));
end

[maxAvg2025, idxMax2025] = max(periodAvgs2025);
[minAvg2025, idxMin2025] = min(periodAvgs2025);
fprintf("\n2025 Highest 3‐month average: %s = %.2f\n", ...
    periodLabels2025(idxMax2025), maxAvg2025);
fprintf("2025 Lowest  3‐month average: %s = %.2f\n", ...
    periodLabels2025(idxMin2025), minAvg2025);

fprintf("2025 Highest Energy Price: %.2f\n", max(cost2025))
fprintf("2050 Highest Energy Price: %.2f\n", max(cost2050))
