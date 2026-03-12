%% CINAR_Setup_figure.m
% Reference map showing all CINAR analysis polygons, auxiliary isobath
% contours (GMB 200m, JB 250m), and fixed mooring/station locations.
% This figure documents the spatial design of the CINAR prey availability
% analysis and is not part of the automated processing workflow.
%
% Output: regions_map.png

clc; clear; close all;
set(0, 'DefaultFigureRenderer', 'painters');

%% Paths
% Repository root — resolved from the location of this script file.
work_dir = fileparts(mfilename('fullpath'));
addpath(work_dir);

%% Load polygon coordinate files
load(fullfile(work_dir, 'Browns_line.txt'));
load(fullfile(work_dir, 'Halifax_line.txt'));
load(fullfile(work_dir, 'JB_deep_latlon.csv'));
load(fullfile(work_dir, 'GeorgesNEC_deep_latlon.csv'));
load(fullfile(work_dir, 'GMB_150_latlon.csv'));
load(fullfile(work_dir, 'GMB_200_latlon.csv'));
load(fullfile(work_dir, 'BOF_latlon.csv'));
load(fullfile(work_dir, 'WSS_broad.csv'));
load(fullfile(work_dir, 'EGOM_broad.csv'));
load(fullfile(work_dir, 'JB_250_latlon.csv'));

% Halifax H2 mooring location
H2 = [-63.3167 44.2667];

% Browns Bank Line (BBL) transect — shortened version
BBL = [
    -65.48   43.25;
    -65.48   43.00;
    -65.4833 42.76;
    -65.4833 42.45;
    -65.5    42.1333;
    -65.51   42.00
];

%% Load Gulf of Maine coastline
% NOTE: GOM3_coast.mat must be on the MATLAB path or in work_dir.
% If missing, contact the workflow maintainer for this file.
load('GOM3_coast.mat');
GOM3_coast(GOM3_coast(:,2) < 40 | GOM3_coast(:,2) > 47, :) = [];
GOM3_coast(GOM3_coast(:,1) < -71 | GOM3_coast(:,1) > -60, :) = [];

%% Initialise figure
f = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 8 6]);
hold on;

%% Define polygon fill colours
colorEGOM    = [0.6, 0.8, 0.5];
colorWSS     = [0.4, 0.5, 0.6];
colorBOF     = [0.4, 0.5, 0.9];
colorJB      = [0.5, 0.5, 0.5];
colorBrowns  = [0.5, 0.6, 0.5];
colorHalifax = [0.8, 0.6, 0.4];
colorGMB     = [0.7, 0.7, 0.7];
colorGMBdeep = [0.3, 0.3, 0.3];
colorNEC     = [0.8, 0.8, 0.8];

%% Plot polygons
fill(EGOM_broad(:,1),           EGOM_broad(:,2),           colorEGOM,    'EdgeColor', 'none');
fill(WSS_broad(:,1),            WSS_broad(:,2),            colorWSS,     'EdgeColor', 'none');
fill(BOF_latlon(:,1),           BOF_latlon(:,2),           colorBOF,     'EdgeColor', 'none');
fill(JB_deep_latlon(:,1),       JB_deep_latlon(:,2),       colorJB,      'EdgeColor', 'w');
fill(Browns_line(:,1),          Browns_line(:,2),          colorBrowns,  'EdgeColor', 'none');
fill(Halifax_line(:,1),         Halifax_line(:,2),         colorHalifax, 'EdgeColor', 'none');
fill(GMB_150_latlon(:,1),       GMB_150_latlon(:,2),       colorGMB,     'EdgeColor', 'w');
fill(GMB_200_latlon(:,1),       GMB_200_latlon(:,2),       colorGMBdeep, 'EdgeColor', 'w');
fill(JB_250_latlon(:,1),        JB_250_latlon(:,2),        colorGMB,     'EdgeColor', 'w');
fill(GeorgesNEC_deep_latlon(:,1),GeorgesNEC_deep_latlon(:,2),colorNEC,   'EdgeColor', 'w');

%% Plot BBL transect
plot(BBL(:,1), BBL(:,2), '-', 'Color', 'm', 'LineWidth', 2);

%% Plot fixed stations / moorings
plot(-66.8500, 44.9300, 'd', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0, 1, 0],   'MarkerSize', 6); % Prince 5
plot(-67.87,   43.5,    '^', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0, 1, 1],   'MarkerSize', 6); % JB Buoy M
plot(-65.9,    42.34,   'v', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0, 0, 1],   'MarkerSize', 6); % NEC Buoy N
plot(H2(1),    H2(2),   's', 'MarkerEdgeColor', [0.9, 0.9, 0.9], 'MarkerFaceColor', 'm', 'MarkerSize', 7); % Halifax H2

%% Plot coastline
plot(GOM3_coast(:,1), GOM3_coast(:,2), '-', 'Color', [0.2, 0.2, 0.2], 'LineWidth', 1.5);

%% Axis limits
xlim([-71 -60]);
ylim([40 47]);

%% Legend (dummy handles for filled patches)
h_egom    = fill(NaN, NaN, colorEGOM,    'EdgeColor', 'none');
h_wss     = fill(NaN, NaN, colorWSS,     'EdgeColor', 'none');
h_bof     = fill(NaN, NaN, colorBOF,     'EdgeColor', 'none');
h_jb      = fill(NaN, NaN, colorJB,      'EdgeColor', 'w');
h_browns  = fill(NaN, NaN, colorBrowns,  'EdgeColor', 'none');
h_halifax = fill(NaN, NaN, colorHalifax, 'EdgeColor', 'none');
h_gmb150  = fill(NaN, NaN, colorGMB,     'EdgeColor', 'w');
h_gmb200  = fill(NaN, NaN, colorGMBdeep, 'EdgeColor', 'w');
h_nec     = fill(NaN, NaN, colorNEC,     'EdgeColor', 'w');
h_bbl     = plot(NaN, NaN, '-',  'Color', 'm', 'LineWidth', 2);
h_p5      = plot(NaN, NaN, 'd',  'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0, 1, 0],   'MarkerSize', 6);
h_jbbuoy  = plot(NaN, NaN, '^',  'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0, 1, 1],   'MarkerSize', 6);
h_necbuoy = plot(NaN, NaN, 'v',  'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0, 0, 1],   'MarkerSize', 6);
h_h2      = plot(NaN, NaN, 's',  'MarkerEdgeColor', [0.9, 0.9, 0.9], 'MarkerFaceColor', 'm', 'MarkerSize', 7);

legend([h_egom, h_wss, h_bof, h_jb, h_browns, h_halifax, h_gmb150, h_gmb200, h_nec, ...
        h_bbl, h_p5, h_jbbuoy, h_necbuoy, h_h2], ...
       {'EGOM', 'WSS', 'BoF', 'Jordan Basin', 'Browns Bank to Halifax Line', ...
        'Eastern Scotian Shelf', 'GMB 150m', 'GMB 200m', 'Georges and NEC', ...
        'Browns Bank Line', 'Prince 5', 'JB Buoy M', 'NEC Buoy N', 'Halifax H2'}, ...
       'Location', 'eastoutside');

xlabel('Longitude');
ylabel('Latitude');
axis equal;
grid on;
set(f, 'Visible', 'on');

%% Save figure
figures_dir = fullfile(work_dir, 'figures');
if ~exist(figures_dir, 'dir'); mkdir(figures_dir); end
exportgraphics(gcf, fullfile(figures_dir, 'regions_map.png'), 'Resolution', 600);
