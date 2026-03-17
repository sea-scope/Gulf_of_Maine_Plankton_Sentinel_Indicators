**SDM Calanus Prey Layer Data --- Access and Use Workflow**

Dataset: DFO Calanus species distribution model outputs, 1999--2024
Maintained by: Cameron Thompson, NERACOOS (cameron@neracoos.org) Last
updated: March 2026

**Overview**

This document describes how to access, transfer, and work with the DFO
SDM Calanus prey layer dataset (1999--2024). The data are stored on the
WHOI HPC server Poseidon and can be copied to local machines or used
directly in analysis workflows on the cluster.

**Data Product Background**

The dataset was developed by Stéphane Plourde and colleagues at DFO\'s
Maurice-Lamontagne Institute. The core methodology:

-   Integrates Calanus spp. abundance observations from both DFO AZMP
    and NOAA EcoMon/MARMAP surveys

-   Accounts for differences in sampling gear and sample depth by
    fitting a GAM to vertically stratified data

-   Converts stage-specific abundance (CIV--adult) to biomass estimates

-   Uses GAM/SDM to predict biomass for three Calanus species as a
    function of location, month, and year across the Northwest Atlantic

The 3D biomass product (10 m depth bins, April--September, 1999--2024)
is the primary input to the processing workflow described below. DFO
also produced a derived energy-availability product for North Atlantic
right whale (NARW) foraging habitat assessment; that component is not
used in the current workflow.

Contact with this dataset was established through Catherine Johnson, who
connected us with Caroline Lehoux at DFO. The 1999--2024 update was
prepared by Eve Rioux and Caroline Lehoux, with input data from AZMP and
EcoMon surveys through 2024.

For questions about the data itself, contact:

-   Caroline Lehoux --- caroline.lehoux@dfo-mpo.gc.ca

-   Eve Rioux --- Eve.Rioux@dfo-mpo.gc.ca

**Where the Data Live**

On Poseidon (WHOI HPC):
/vortexfs1/share/jilab/DFO_SPM_Calanus_1999_2024/SDM_Calanus_1999-2024_ERioux/

Key subdirectories:

-   Bioenergy/ --- Depth-integrated bioenergy predictions

-   Bioenergy_3D/ --- 3D bioenergy predictions by depth layer

Excel readme files in the root directory:

-   readME_bioenergy_predictions_1999-2024.xlsx

-   readME_Zlayer3D_predictions_1999-2024.xlsx

On Local Windows Machine (OneDrive): C:\\Users\\camer\\OneDrive - Woods
Hole Oceanographic Institution\\Data\\

**Step 1 --- Obtaining the Source Data from DFO**

The original dataset was downloaded from a DFO FTP server as a single
zip archive (\~10 GB). This step only needs to be repeated if the
dataset needs to be re-acquired (e.g., updated version from DFO).

FTP source (may expire):
ftp://ftp.dfo-mpo.gc.ca/Public/20260303/SDM_Calanus_1999-2024_ERioux.zip

If the FTP link has expired, contact DFO (see contacts above) to request
access.

Download and Extract on Poseidon:

SSH into Poseidon, navigate to the target directory, and run:

nohup bash -c \'wget
ftp://ftp.dfo-mpo.gc.ca/Public/20260303/SDM_Calanus_1999-2024_ERioux.zip
&& UNZIP_DISABLE_ZIPBOMB_DETECTION=TRUE unzip
SDM_Calanus_1999-2024_ERioux.zip && rm
SDM_Calanus_1999-2024_ERioux.zip\' \> download.log 2\>&1 &

The nohup wrapper runs the job in the background so the terminal session
can be safely closed. Monitor progress with: tail -f download.log

Note: The UNZIP_DISABLE_ZIPBOMB_DETECTION=TRUE flag is required because
the archive is large enough to trigger unzip\'s zip bomb detection.

**Step 2 --- Accessing Data on Poseidon**

Poseidon is WHOI\'s HPC cluster. Access requires a WHOI account and SSH.

Connecting: ssh cameron.thompson@poseidon.whoi.edu

External collaborators will need to request a Poseidon account through
WHOI IT or arrange access via a WHOI-affiliated PI.

Navigating to the data: cd
/vortexfs1/share/jilab/DFO_SPM_Calanus_1999_2024/SDM_Calanus_1999-2024_ERioux/

Data can be used directly on the cluster for computationally intensive
work (e.g., running R scripts via SLURM jobs) without needing to copy
files locally.

**Step 3 --- Copying Data to a Local Machine**

For local analysis, subdirectories can be transferred from Poseidon to a
local machine using rsync.

Prerequisites:

-   MobaXterm (recommended for Windows users) or any terminal with
    SSH/rsync access

-   Active Poseidon credentials

How MobaXterm Maps Windows Drives: MobaXterm exposes Windows drives
under /drives/. To confirm your mapping: ls /drives Typical output: c h
j --- meaning C:\\ is accessible as /drives/c.

Running the Transfer: Open a local MobaXterm terminal (not an SSH
session into Poseidon) and run rsync from there.

Example --- copy Bioenergy_3D/ to local OneDrive: rsync -avz
cameron.thompson@poseidon.whoi.edu:/vortexfs1/share/jilab/DFO_SPM_Calanus_1999_2024/SDM_Calanus_1999-2024_ERioux/Bioenergy_3D
\"/drives/c/Users/camer/OneDrive - Woods Hole Oceanographic
Institution/Data/\"

Important: Quotes are required around the destination path because of
the space in \"OneDrive - Woods Hole Oceanographic Institution\".

rsync flags:

-   -a: Archive mode --- preserves permissions, timestamps, symlinks

-   -v: Verbose --- prints files as they transfer

-   -z: Compress data during transfer

-   -P: Show progress and allow resuming interrupted transfers
    (recommended for large transfers)

**Step 4 --- Processing the Data in R**

The analysis workflow transforms the raw 3D biomass predictions into
depth-integrated, spatially summarized time series suitable for use as
prey availability indices. It consists of four sequential scripts.

**4.1 Depth Integration --- DFO_data_process.r**

Input: Raw 3D biomass data (10 m depth bins), one spreadsheet per year
(1999--2024) and months (only april to september now)

What it does:

-   Integrates Calanus biomass into two vertical layers: shallow
    (0--80 m) and deep (\>80 m)

-   Filters output to six key regions: CCB, Fundy, GB, GOM, SNE, SS

Output: CSV files with depth-integrated biomass by layer\
\
\# need to update so all months processed\
\# need another column of total (full water column) integrated biomass\
\# need to check/verify regions

**4.2 Spatial Assignment --- Data_layer_polygons.m**

Note: this step runs in MATLAB, not R.

Input: Depth-integrated biomass CSVs from Step 4.1

What it does:

-   Loads polygon boundaries for two spatial frameworks: CINAR regions
    (8 polygons) and EcoMon survey strata

-   For each coordinate in the biomass data, determines which polygon it
    falls within

-   Appends polygon assignment columns to each record

Output: CSV files with spatial polygon assignments added\
\
\# be better to port this to r\
\# need to identify the file dependencies that should be organized
locally and put on git

**4.3 Summary Creation --- DFO_data_polygon_summary.r**

Input: Spatially assigned biomass CSVs from Step 4.2

What it does:

-   Filters out sites deeper than 500 m, north of 46°N, and east of 60°W

-   Computes mean and SE of biomass (shallow and deep layers separately)
    by polygon, year, and month\
    \# note the se isn't really variance, it's just indicating something
    about the data spread across the polygon, shallow areas will
    obviously have lower biomass compared to deep areas. perhaps there
    is a better metric? Maybe we should be recording variance in the
    concentration? density?

-   Note: coordinate locations are fixed across years and months, so a
    straightforward mean captures seasonal and interannual variability
    within each polygon. This is appropriate as a model input but should
    be interpreted carefully as a regional mean biomass descriptor.

-   Binds annual/monthly spreadsheets into a single time series per
    spatial framework

Output:

-   DFO_biomass_CINAR_summary.csv --- polygon-level biomass time series
    for CINAR regions

-   DFO_biomass_EcoMon_summary.csv --- polygon-level biomass time series
    for EcoMon strata

**4.4 Visualization --- DFO_biomass_visualization_CINAR.r**

Input: DFO_biomass_CINAR_summary.csv

What it does:

-   Generates seasonal plots showing biomass patterns across years

-   Error bars represent SE across sites within each polygon

**Step 5 --- Archiving and Long-Term Storage**

(To be documented)

**Notes on the Dataset**

-   The 2024 update has a slightly reduced spatial extent compared to
    the previous (1999--2023) version. Data in the Northumberland Strait
    and upper Bay of Fundy have been removed, and the western boundary
    was pulled in slightly. See correspondence with Caroline Lehoux for
    details.

-   There is known uncertainty in C. glacialis spring predictions on the
    Labrador coast due to lack of spring survey coverage in that area.

-   The underlying methodology is described in: Plourde et al. (2024),
    CSAS Research Document 2024/039, Quebec Region.

**Contacts**

-   Cameron Thompson, NERACOOS --- cameron@neracoos.org (workflow
    maintainer)

-   Caroline Lehoux, DFO-MLI --- caroline.lehoux@dfo-mpo.gc.ca

-   Eve Rioux, DFO-MLI --- Eve.Rioux@dfo-mpo.gc.ca

Once you\'ve pasted it in, use Google Docs\' \"Styles\" dropdown to
apply Heading 1/2/3 formatting to the bold section titles and it\'ll be
fully structured. Want me to note anything else to add before you do
that?

\####\
Reorganizing

New (temporary) location\
C:\\Users\\camer\\Desktop\\SPM_calanus_biomass

Contains

Directory biodenergy_3D

BOF_latlon.csv CINAR_Setup_figure.m DFO_biomass_visualization_EcoMon.R
Data_layer_Polygons.m GMB_200_latlon.csv Halifax_line.txt
JB_deep_latlon.csv

Bioenergy_3D DFO_CINAR_polygon_map.R DFO_data_polygon_summary.R
EGOM_broad.csv GMB_200_sp.csv Inset_map.R PT_track_presentation_map.R

Biomass_interannual_4_plot.R DFO_biomass_visualization.R
DFO_data_process.R GMB_150_latlon.csv GeorgesNEC_deep_latlon.csv
JB_250_latlon.csv WSS_broad.csv

Browns_line.txt DFO_biomass_visualization_CINAR.R DFO_exploration.R
GMB_150_sp.csv GeorgesNEC_deep_sp.csv JB_250_sp.csv sp_proj.m

\## this all might be dated
