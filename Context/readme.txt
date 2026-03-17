SDM Calanus Prey Layer Data (1999-2024)
========================================

Overview
--------
This directory contains Calanus species distribution model (SDM) outputs
produced by DFO (Fisheries and Oceans Canada), covering 1999-2024. The
models predict seasonal and spatial distributions of Calanus species and
North Atlantic right whale potential foraging habitats across the
Northwest Atlantic, from the Mid-Atlantic Bight to Labrador.

The underlying methodology is described in:

  Plourde, S., Lehoux, C., Roberts, J.J., Johnson, C.L., Record, N.,
  Pepin, P., Orphanides, C., Schick, R.S., Walsh, H.J., Ross, C.H.
  (2024). Describing the Seasonal and Spatial Distribution of Calanus
  Species and North Atlantic Right Whale Potential Foraging Habitats in
  Canadian Waters Using Species Distribution Models. Canadian Science
  Advisory Secretariat (CSAS) Research Document 2024/039, Quebec Region.

The 1999-2024 update was prepared by Eve Rioux and Caroline Lehoux at
DFO's Maurice-Lamontagne Institute, with input data from AZMP and EcoMon
surveys through 2024.

Contents
--------
- Bioenergy/          Depth-integrated and 3D bioenergy predictions
- Bioenergy_3D/       3D bioenergy predictions by depth layer
- readME_bioenergy_predictions_1999-2024.xlsx
- readME_Zlayer3D_predictions_1999-2024.xlsx

See the Excel readme files for detailed variable descriptions.

Data Access
-----------
The source zip file (~10 GB) is available via FTP for a limited time:

  ftp://ftp.dfo-mpo.gc.ca/Public/20260303/SDM_Calanus_1999-2024_ERioux.zip

To download and extract on a remote Linux server, SSH in, navigate to
your target directory, and run:

  nohup bash -c 'wget ftp://ftp.dfo-mpo.gc.ca/Public/20260303/SDM_Calanus_1999-2024_ERioux.zip && UNZIP_DISABLE_ZIPBOMB_DETECTION=TRUE unzip SDM_Calanus_1999-2024_ERioux.zip && rm SDM_Calanus_1999-2024_ERioux.zip' > download.log 2>&1 &

This runs the download in the background so you can disconnect. Check
progress with: tail -f download.log 

The file is large enough that unzip may flag it as a potential zip bomb.
The UNZIP_DISABLE_ZIPBOMB_DETECTION=TRUE variable overrides that check.

Note that the FTP link may expire. If the link is no longer active,
contact Caroline Lehoux (caroline.lehoux@dfo-mpo.qc.ca) or Eve Rioux
(Eve.Rioux@dfo-mpo.gc.ca) at DFO to request access.

Notes
-----
- The 2024 update has a slightly reduced spatial extent compared to the
  previous (1999-2023) version. Data in the Northumberland Strait and
  upper Bay of Fundy have been removed, and the western boundary was
  pulled in slightly. See correspondence with Caroline Lehoux for details.

- There is known uncertainty in C. glacialis spring predictions on the
  Labrador coast due to lack of spring survey coverage in that area.

Contact
-------
Cameron Thompson, NERACOOS (cameron@neracoos.org)