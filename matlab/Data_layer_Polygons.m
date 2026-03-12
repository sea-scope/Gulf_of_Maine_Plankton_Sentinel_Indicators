%% MATLAB code for coordinate location tracking and polygon assignment
% Step 2 of the DFO Calanus biomass processing workflow.
% Assigns each depth-integrated grid point (from DFO_data_process.R output)
% to a CINAR region polygon and an EcoMon survey stratum.
%
% Inputs:  *_processed.csv files (one per month/year) from input_dir
% Outputs: *_processed_polygons.csv files with CINAR_poly and EcoMon_poly columns
%
% CINAR polygon ID mapping:
%   1 = WSS (Western Scotian Shelf)
%   2 = EGOM (Eastern Gulf of Maine)
%   3 = JB (Jordan Basin)
%   4 = Browns (Browns Bank)
%   5 = Halifax (Eastern Scotian Shelf)
%   6 = GeorgesNEC (Georges Basin and NE Channel)
%   7 = GMB150 (Grand Manan Basin, 150 m isobath)
%   8 = BOF (Bay of Fundy)
%   0 = Unassigned
%
% Assignment priority (highest first): GMB150 > JB > GeorgesNEC > BOF > WSS > EGOM > Browns > Halifax
% A point is assigned to the first polygon in this sequence that contains it.
%
% NOTE: For a faster, fully-R implementation see Data_layer_Polygons.R,
% which replicates this logic using sf::st_difference() + sf::st_join().

clc; clear; close all;

%% Paths
% Repository root — resolved from the location of this script file.
work_dir   = fileparts(mfilename('fullpath'));
input_dir  = fullfile(work_dir, 'processed');
output_dir = fullfile(work_dir, 'polygons');

% sp_proj.m lives in work_dir; add it to path
addpath(work_dir);

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% Load polygon coordinate files
% All files are in decimal degrees (lon, lat).
% GMB_150 and GeorgesNEC use the _latlon.csv versions directly.
% The _sp.csv (state plane) files are not used here.
fprintf('Loading polygon coordinate files...\n');

Browns_line            = load(fullfile(work_dir, 'Browns_line.txt'));
Halifax_line           = load(fullfile(work_dir, 'Halifax_line.txt'));
JB_deep_latlon         = readmatrix(fullfile(work_dir, 'JB_deep_latlon.csv'));
GeorgesNEC_deep_latlon = readmatrix(fullfile(work_dir, 'GeorgesNEC_deep_latlon.csv'));
GMB_150_latlon         = readmatrix(fullfile(work_dir, 'GMB_150_latlon.csv'));
BOF_latlon             = readmatrix(fullfile(work_dir, 'BOF_latlon.csv'));
WSS_broad              = readmatrix(fullfile(work_dir, 'WSS_broad.csv'));
EGOM_broad             = readmatrix(fullfile(work_dir, 'EGOM_broad.csv'));

%% Prepare EcoMon shape objects
fprintf('Loading EcoMon polygons from EMstrata_v4.mat...\n');
load(fullfile(work_dir, 'EMstrata_v4.mat'));

% Build polyshape objects for EcoMon strata indices 14-47.
% These index values match the NES stratum numbering in EMstrata_v4.
EcoMonshape = polyshape.empty;
for j = 14:47
    x = EMstrata_v4(j).x;
    y = EMstrata_v4(j).y;
    EcoMonshape(j) = polyshape(x, y);
end

%% Prepare CINAR shape objects
fprintf('Creating CINAR polygon shapes...\n');

% Extract coordinates (column 1 = lon, column 2 = lat throughout)
JB_x         = JB_deep_latlon(:, 1);
JB_y         = JB_deep_latlon(:, 2);
Browns_x     = Browns_line(:, 1);
Browns_y     = Browns_line(:, 2);
Halifax_x    = Halifax_line(:, 1);
Halifax_y    = Halifax_line(:, 2);
BOF_x        = BOF_latlon(:, 1);
BOF_y        = BOF_latlon(:, 2);
WSS_x        = WSS_broad(:, 1);
WSS_y        = WSS_broad(:, 2);
EGOM_x       = EGOM_broad(:, 1);
EGOM_y       = EGOM_broad(:, 2);
GMB150_x     = GMB_150_latlon(:, 1);
GMB150_y     = GMB_150_latlon(:, 2);
GeorgesNEC_x = GeorgesNEC_deep_latlon(:, 1);
GeorgesNEC_y = GeorgesNEC_deep_latlon(:, 2);

% Create CINAR polyshape objects; index = CINAR_poly ID
shape(1) = polyshape(WSS_x,        WSS_y);        % 1 = WSS
shape(2) = polyshape(EGOM_x,       EGOM_y);       % 2 = EGOM
shape(3) = polyshape(JB_x,         JB_y);         % 3 = JB
shape(4) = polyshape(Browns_x,     Browns_y);     % 4 = Browns
shape(5) = polyshape(Halifax_x,    Halifax_y);    % 5 = Halifax
shape(6) = polyshape(GeorgesNEC_x, GeorgesNEC_y); % 6 = GeorgesNEC
shape(7) = polyshape(GMB150_x,     GMB150_y);     % 7 = GMB150
shape(8) = polyshape(BOF_x,        BOF_y);        % 8 = BOF

% Polygon names indexed by CINAR_poly ID (used in summary output)
polygon_names = {'WSS', 'EGOM', 'JB', 'Browns', 'Halifax', 'GeorgesNEC', 'GMB150', 'BOF'};

%% Get list of processed CSV files
csv_files = dir(fullfile(input_dir, '*_processed.csv'));
fprintf('Found %d processed CSV files to analyze\n', length(csv_files));

%% Process each CSV file
for file_idx = 1:length(csv_files)
    filename = csv_files(file_idx).name;
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('Processing file: %s\n', filename);

    filepath = fullfile(input_dir, filename);

    try
        data_table_full = readtable(filepath);
        fprintf('Loaded data: %d rows x %d columns\n', height(data_table_full), width(data_table_full));

        % Check required columns
        required_vars = {'X', 'Y', 'REGION'};
        if ~all(ismember(required_vars, data_table_full.Properties.VariableNames))
            fprintf('Warning: Required columns (X, Y, REGION) not found in %s. Skipping.\n', filename);
            continue;
        end

        % Filter to the six DFO source regions used in the analysis
        desired_regions = {'CCB', 'Fundy', 'GB', 'GOM', 'SNE', 'SS'};
        data_table = data_table_full(ismember(data_table_full.REGION, desired_regions), :);
        fprintf('After regional filter: %d rows remaining\n', height(data_table));

        if height(data_table) == 0
            fprintf('Warning: No data remaining after regional filtering. Skipping.\n');
            continue;
        end

        % Initialise assignment columns (0 = unassigned)
        data_table.CINAR_poly  = zeros(height(data_table), 1);
        data_table.EcoMon_poly = zeros(height(data_table), 1);

        %% CINAR polygon assignment
        fprintf('Assigning CINAR polygons...\n');
        for i = 1:height(data_table)
            if mod(i, 1000) == 0
                fprintf('  Processing row %d of %d\n', i, height(data_table));
            end

            pt_x = data_table.X(i);
            pt_y = data_table.Y(i);

            if isnan(pt_x) || isnan(pt_y)
                continue;
            end

            % Priority order: GMB150(7), JB(3), GeorgesNEC(6), BOF(8),
            %                 WSS(1), EGOM(2), Browns(4), Halifax(5)
            for shape_idx = [7, 3, 6, 8, 1, 2, 4, 5]
                if isinterior(shape(shape_idx), pt_x, pt_y)
                    data_table.CINAR_poly(i) = shape_idx;
                    break;
                end
            end
        end

        %% EcoMon polygon assignment
        fprintf('Assigning EcoMon polygons...\n');
        for i = 1:height(data_table)
            if mod(i, 1000) == 0
                fprintf('  Processing row %d of %d\n', i, height(data_table));
            end

            pt_x = data_table.X(i);
            pt_y = data_table.Y(i);

            if isnan(pt_x) || isnan(pt_y)
                continue;
            end

            for j = 14:47
                if ~isempty(EcoMonshape(j).Vertices) && isinterior(EcoMonshape(j), pt_x, pt_y)
                    data_table.EcoMon_poly(i) = j;
                    break;
                end
            end
        end

        %% Save output
        [~, base_name, ~] = fileparts(filename);
        output_filename   = [base_name, '_polygons.csv'];
        output_filepath   = fullfile(output_dir, output_filename);
        writetable(data_table, output_filepath);

        %% Print assignment summary
        cinar_counts       = histcounts(data_table.CINAR_poly, 0.5:8.5);
        n_unassigned_cinar = sum(data_table.CINAR_poly == 0);
        ecomon_assigned    = sum(data_table.EcoMon_poly > 0);

        fprintf('CINAR polygon assignments:\n');
        for i = 1:8
            if cinar_counts(i) > 0
                fprintf('  %s (%d): %d points\n', polygon_names{i}, i, cinar_counts(i));
            end
        end
        fprintf('  Unassigned: %d points\n', n_unassigned_cinar);
        fprintf('EcoMon assignments: %d points assigned\n', ecomon_assigned);
        fprintf('Saved: %s\n', output_filename);

    catch ME
        fprintf('Error processing file %s: %s\n', filename, ME.message);
    end
end

fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('Processing complete!\n');
fprintf('Output files saved to: %s\n', output_dir);
