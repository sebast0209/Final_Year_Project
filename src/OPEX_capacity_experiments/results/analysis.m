%--------------OPEX Capacity Experiments-----------------------------------

clear;
clc;

figPos = [100, 100, 500, 300];

% 1) Experiment 1: ObjValue vs ProdCap (as multiples of baseline)
T1 = readtable('results/experiment1a.xlsx', 'Sheet', 'Exp1_Results');
prodCap1       = T1.ProdCap;
obj1           = T1.ObjValue;
CAPEX_OPEX1    = T1.CAPEX_OPEX;

% Sort
[prodCap1_sorted, idx1]      = sort(prodCap1);
obj1_sorted                  = obj1(idx1);
CAPEX_OPEX1_sorted           = CAPEX_OPEX1(idx1);

% Identify baseline (assume the smallest capacity is baseline)
baseline = prodCap1_sorted(1);

% Compute multiples of baseline
multiples = prodCap1_sorted / baseline;

figure('Name','Exp 1: Objective vs ProdCap Multiple','NumberTitle','off','Position',figPos);
plot(multiples, obj1_sorted, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
% Keep the auto ticks but append 'x'
xt = get(gca,'XTick');
xticklabels(strcat(string(xt),'x'));
xlabel('Production Capacity (times baseline)');
ylabel('OPEX ($)');
title('OPEX vs. Capacity Multiple');
grid on;

% Plot CAPEX+OPEX vs multiples, same tick formatting
figure('Name','Exp 1: CAPEX+OPEX vs ProdCap Multiple','NumberTitle','off','Position',figPos);
plot(multiples, CAPEX_OPEX1_sorted, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
xt = get(gca,'XTick');
xticklabels(strcat(string(xt),'x'));
xlabel('Production Capacity (times baseline)');
ylabel('CAPEX + OPEX ($)');
title('CAPEX+OPEX vs. Capacity Multiple');
grid on;



% 2) Experiment 2: ObjValue vs InvCapUp
T2 = readtable('results/experiment2a.xlsx', 'Sheet', 'Exp2_Results');
invCapUp2 = T2.InvCapUp;
obj2      = T2.ObjValue;
CAPEX_OPEX2 = T2.CAPEX_OPEX;

figure('Name','Exp 2: ObjValue vs InvCapUp','NumberTitle','off', 'Position', figPos);
semilogx(invCapUp2, obj2, 's-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('Upstream Inventory Capacity (tonnes)');
ylabel('OPEX ($)');
title('OPEX vs. Upstream Inv. Capacity');
grid on;

figure('Name','Exp 2: CAPEX+OPEX vs InvCapUp','NumberTitle','off', 'Position', figPos);
semilogx(invCapUp2, CAPEX_OPEX2, 's-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('Upstream Inventory Capacity (tonnes)');
ylabel('CAPEX+OPEX ($)');
title('CAPEX+OPEX vs. Upstream Inv. Capacity');
grid on;

% 3) Experiment 3: ObjValue vs InvCapDown
T3 = readtable('results/experiment3a.xlsx', 'Sheet', 'Exp3_Results');
invCapDown3 = T3.InvCapDown;
obj3        = T3.ObjValue;
CAPEX_OPEX3 = T3.CAPEX_OPEX;

figure('Name','Exp 3: ObjValue vs InvCapUp','NumberTitle','off', 'Position', figPos);
semilogx(invCapDown3, obj3, 's-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('Downstream Inventory Capacity (tonnes)');
ylabel('OPEX ($)');
title('OPEX vs. Downstream Inv. Capacity');
grid on;

figure('Name','Exp 3: CAPEX\\+OPEX vs InvCapDown','NumberTitle','off', 'Position', figPos);
semilogx(invCapDown3, CAPEX_OPEX3, 'd-', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('Downstream Inventory Capacity (tonnes)');
ylabel('CAPEX+OPEX ($)');
title('CAPEX+OPEX vs. Downstream Inv. Capacity');
grid on;







