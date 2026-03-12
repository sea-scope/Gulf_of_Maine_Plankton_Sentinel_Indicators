%% export_for_R.m
% Exports particle Lon/Lat and polygon boundaries as CSVs for R plotting.
% Run this from the particle tracking output directory (e.g., standardsta_fit_20140505).

clc; clear; close all;

% sp_proj.m is in the working directory (required for particle coordinate conversion)
addpath('C:/Users/camer/Desktop/SPM_calanus_biomass');

datapath = 'C:/Users/camer/Desktop/SPM_calanus_biomass/';
outpath  = 'C:/Users/camer/OneDrive - Woods Hole Oceanographic Institution/R/CINAR/';

%% Read simulation metadata from directory name and namelist

[~, current_directory_name, ~] = fileparts(pwd);
year_str = current_directory_name(end-7:end-4);
sim_year = str2double(year_str);

fid = fopen('standard_sta_fit.nml', 'r');
fgetl(fid);
line2 = fgetl(fid);
tokens = regexp(line2, 'beg_time_days\s*=\s*([\d.]+)', 'tokens');
beg_time_days = str2double(tokens{1}{1});
fclose(fid);

dateNum = datenum(sim_year, 1, 0) + beg_time_days;
date_tag = datestr(dateNum, 'yyyymmdd');

%% Read NetCDF and convert coordinates

fname = './fiscm_group_001.nc';
x = ncread(fname, 'x');
y = ncread(fname, 'y');

N = size(x, 1);
T = size(x, 2);

% Convert all time steps from state plane to lat/lon
Lon = zeros(N, T);
Lat = zeros(N, T);
for t = 1:T
    [Lon(:,t), Lat(:,t)] = sp_proj('1802', 'inverse', x(:,t), y(:,t), 'm');
end

% Export
writematrix(Lon, fullfile(outpath, ['Lon_' date_tag '.csv']));
writematrix(Lat, fullfile(outpath, ['Lat_' date_tag '.csv']));
fprintf('Exported Lon/Lat for %s (%d particles x %d timesteps)\n', date_tag, N, T);

%% Export polygon boundaries as clipped lat/lon CSVs (only need to run once)
% Priority order (highest first, matching isinterior logic):
%   GMB_150 > JB > Georges_NEC > BOF > WSS > EGOM > Browns > Halifax
% Each polygon gets all higher-priority polygons subtracted.

% Load all polygon data
EGOM_broad    = load(fullfile(datapath, 'EGOM_broad.csv'));
WSS_broad     = load(fullfile(datapath, 'WSS_broad.csv'));
BOF_latlon    = load(fullfile(datapath, 'BOF_latlon.csv'));
JB_deep       = load(fullfile(datapath, 'JB_deep_latlon.csv'));
Browns_line   = load(fullfile(datapath, 'Browns_line.txt'));
Halifax_line  = load(fullfile(datapath, 'Halifax_line.txt'));
GMB_150       = load(fullfile(datapath, 'GMB_150_latlon.csv'));
GMB_200       = load(fullfile(datapath, 'GMB_200_latlon.csv'));
JB_250        = load(fullfile(datapath, 'JB_250_latlon.csv'));
GeorgesNEC    = load(fullfile(datapath, 'GeorgesNEC_deep_latlon.csv'));

% Build polyshape objects (lon, lat)
ps_GMB150  = polyshape(GMB_150(:,1),    GMB_150(:,2));
ps_JB      = polyshape(JB_deep(:,1),    JB_deep(:,2));
ps_GBNEC   = polyshape(GeorgesNEC(:,1), GeorgesNEC(:,2));
ps_BOF     = polyshape(BOF_latlon(:,1), BOF_latlon(:,2));
ps_WSS     = polyshape(WSS_broad(:,1),  WSS_broad(:,2));
ps_EGOM    = polyshape(EGOM_broad(:,1), EGOM_broad(:,2));
ps_Browns  = polyshape(Browns_line(:,1),Browns_line(:,2));
ps_Halifax = polyshape(Halifax_line(:,1),Halifax_line(:,2));
ps_GMB200  = polyshape(GMB_200(:,1),   GMB_200(:,2));
ps_JB250   = polyshape(JB_250(:,1),    JB_250(:,2));

% Clip in priority order
fprintf('Clipping polygons...\n');

% GMB_150: highest priority, no clipping
clip_GMB150  = ps_GMB150;

% JB: subtract GMB_150
clip_JB      = subtract(ps_JB, ps_GMB150);

% Georges NEC: subtract GMB_150, JB
clip_GBNEC   = subtract(ps_GBNEC, ps_GMB150);
clip_GBNEC   = subtract(clip_GBNEC, ps_JB);

% BOF: subtract GMB_150, JB, Georges NEC
clip_BOF     = subtract(ps_BOF, ps_GMB150);
clip_BOF     = subtract(clip_BOF, ps_JB);
clip_BOF     = subtract(clip_BOF, ps_GBNEC);

% WSS: subtract GMB_150, JB, Georges NEC, BOF
clip_WSS     = subtract(ps_WSS, ps_GMB150);
clip_WSS     = subtract(clip_WSS, ps_JB);
clip_WSS     = subtract(clip_WSS, ps_GBNEC);
clip_WSS     = subtract(clip_WSS, ps_BOF);

% EGOM: subtract GMB_150, JB, Georges NEC, BOF, WSS
clip_EGOM    = subtract(ps_EGOM, ps_GMB150);
clip_EGOM    = subtract(clip_EGOM, ps_JB);
clip_EGOM    = subtract(clip_EGOM, ps_GBNEC);
clip_EGOM    = subtract(clip_EGOM, ps_BOF);
clip_EGOM    = subtract(clip_EGOM, ps_WSS);

% Browns: subtract all above
clip_Browns  = subtract(ps_Browns, ps_GMB150);
clip_Browns  = subtract(clip_Browns, ps_JB);
clip_Browns  = subtract(clip_Browns, ps_GBNEC);
clip_Browns  = subtract(clip_Browns, ps_BOF);
clip_Browns  = subtract(clip_Browns, ps_WSS);
clip_Browns  = subtract(clip_Browns, ps_EGOM);

% Halifax: subtract all above
clip_Halifax = subtract(ps_Halifax, ps_GMB150);
clip_Halifax = subtract(clip_Halifax, ps_JB);
clip_Halifax = subtract(clip_Halifax, ps_GBNEC);
clip_Halifax = subtract(clip_Halifax, ps_BOF);
clip_Halifax = subtract(clip_Halifax, ps_WSS);
clip_Halifax = subtract(clip_Halifax, ps_EGOM);
clip_Halifax = subtract(clip_Halifax, ps_Browns);

% GMB_200 and JB_250 are display-only (not used for particle binning)
% Export unclipped
clip_GMB200  = ps_GMB200;
clip_JB250   = ps_JB250;

fprintf('Clipping complete.\n');

% Export clipped polyshapes as CSVs
% boundary() returns NaN-separated vertices for multiregion polyshapes
clip_names = {'GMB_150','JB_deep','GeorgesNEC','BOF_latlon','WSS_broad', ...
              'EGOM_broad','Browns_line','Halifax_line','GMB_200','JB_250'};
clip_polys = {clip_GMB150, clip_JB, clip_GBNEC, clip_BOF, clip_WSS, ...
              clip_EGOM, clip_Browns, clip_Halifax, clip_GMB200, clip_JB250};

for i = 1:length(clip_names)
    [lon, lat] = boundary(clip_polys{i});
    data = [lon, lat];
    dst = fullfile(outpath, ['poly_' clip_names{i} '.csv']);
    writematrix(data, dst);
    fprintf('Exported %s (%d vertices, %d regions)\n', ...
        clip_names{i}, size(data,1), clip_polys{i}.NumRegions);
end

fprintf('Done. All files written to:\n  %s\n', outpath);