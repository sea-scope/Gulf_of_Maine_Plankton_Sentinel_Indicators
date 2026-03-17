Background literature

**Plourde et al. 2024 --- Calanus Species Distribution Models and NARW
Foraging Habitat in Canadian Waters (DFO CSAS Res. Doc. 2024/039)**

**Background and motivation:** The three dominant Calanus species in the
Northwest Atlantic (C. finmarchicus, C. glacialis, C. hyperboreus)
differ substantially in their thermal affinities, phenology, and body
size (up to an order of magnitude difference in individual weight).
Despite extensive monitoring through DFO\'s AZMP and NOAA\'s EcoMon
programs, a comprehensive multispecies description of Calanus
distribution spanning the full geographic range relevant to North
Atlantic right whale foraging had not been done. This paper aims to fill
that gap using data from 1999 to 2020 across a transboundary domain
stretching from the Mid-Atlantic Bight to the Labrador Shelf.

**Data sources and harmonization:** The authors combined zooplankton
observations from AZMP (200 um mesh, surface-to-near-bottom vertical
tows, species and stage resolved) and EcoMon (333 um mesh, oblique Bongo
tows to 200 m max). This required several standardization steps:
restricting analyses to late copepodite stages CIV-CVI (which are
retained similarly by both mesh sizes and are the stages relevant to
right whale feeding), applying vertical distribution corrections to make
EcoMon\'s shallower sampling comparable to AZMP\'s deeper tows, and
excluding stations with bottom depth exceeding 1000 m to maintain a
consistent bathymetric domain. Stations where EcoMon aggregated C.
glacialis and C. hyperboreus into a single taxon were treated as C.
hyperboreus based on the known dominance of that species in the nearest
AZMP-sampled region. The final dataset comprised roughly 16,300
stations.

**Environmental covariates:** Covariate selection was hypothesis-driven
and mechanistically motivated. Temperature in the 0-50 m layer (T_0-50)
and the water column temperature minimum (Tmin) served as proxies for
the thermal environment during the active growth season and
overwintering period, respectively, with the explicit expectation that
arctic vs. subarctic species would show different temperature optima.
Bathymetry was included as a proxy for overwintering habitat
availability. All environmental fields were derived from the GLORYS12v1
ocean reanalysis (1/12 degree resolution, monthly), chosen as the best
available gridded product at this scale despite known biases in surface
salinity in the western Gulf of St. Lawrence.

A key innovation was the \"connectivity\" interaction term, built from
the Supply-Aggregation-Availability conceptual framework. This term
combined latitude (proxy for distance from source populations, given
known north-south abundance gradients), a transformed salinity
climatology of the 0-50 m layer (climS_0-50sqrt, structuring the
seascape into fresher inner-shelf vs. saltier outer-shelf pathways), and
month (capturing species-specific phenology). The salinity
transformation involved subtracting from the 99th percentile value and
taking the square root, which normalized the left-skewed distribution
and inverted the scale so that higher transformed values correspond to
fresher water. These three covariates entered the model as a tensor
product interaction, intended to capture large-scale seasonal patterns
of advective connectivity without requiring a full coupled biophysical
model.

**SDM framework:** Species-specific SDMs were built using Generalized
Additive Mixed Models (GAMMs) in mgcv. Abundance followed a zero-altered
Gamma (ZAG) distribution: a Bernoulli model for presence/absence and a
Gamma model for abundance conditional on presence, combined
multiplicatively for predictions. Year was included as a random
intercept. Several candidate model formulations were tested, varying in
two key dimensions: whether species responses to covariates were assumed
to be uniform across the domain vs. locally adapted (regional
factorization), and whether the connectivity term was included. The
candidates ranged from Model 1 (no regional factorization, no
connectivity term, analogous to earlier SDMs by Albouy-Boyer et al. and
Grieve et al.) through Model 2 (nine regional factors, no connectivity),
to Models 3.1-3.3 (connectivity term included, with varying degrees of
regional factorization). Model 3.3, the best-performing version for C.
finmarchicus and C. hyperboreus, used only four regional factors (sGSL,
Georges Bank, Cape Cod Bay, and one large \"rest of domain\" region)
plus the connectivity term, and additionally Winsorized Tmin at
species-specific thresholds (20 degrees C for C. finmarchicus, 10
degrees C for C. hyperboreus) to prevent occurrences under sub-optimal
conditions driven by passive transport from distorting predictions
elsewhere. For C. glacialis, Winsorizing was not justified, and Model
3.1 (connectivity term, no regional factors) was selected. Smooth terms
used thin plate regression splines with reduced basis dimensions to
avoid overfitting.

**Validation:** Models were evaluated through repeated 70/30 train/test
splits (100 iterations), using True Skill Statistic for the occurrence
component and out-of-sample deviance for the abundance component.
Region-specific correlations between monthly/yearly predicted and
observed abundance were computed. The ZAG distribution was validated
through 10,000 simulations comparing predicted quantiles to
observations.

**Abundance-to-biomass conversion:** Predicted abundance was converted
to dry weight biomass using temperature-dependent body size
relationships from Campbell et al. (2001) for C. finmarchicus, scaled to
the larger species using empirically derived scaling factors (roughly
1.6-2.5x for C. glacialis, 5-8x for C. hyperboreus). Body weights were
constrained to empirically observed bounds (10th-90th percentiles from
Helenius et al. 2023) to avoid unrealistic extrapolation. Stage-specific
relative abundances by region and month were applied to weight the CIV,
CV, and CVI contributions. Carbon-to-dry-weight ratios of 52% for C.
finmarchicus/glacialis and 60% for C. hyperboreus were used.

**Key findings relevant to the SDM data product:** The connectivity term
captured ecologically realistic patterns: C. finmarchicus was associated
with saltier offshore water masses and showed connectivity from the
Grand Banks southward along the shelf from May to August; C. hyperboreus
showed strong connectivity from the nGSL through the sGSL and onto the
Scotian Shelf via the fresher St. Lawrence outflow; C. glacialis showed
connectivity centered on the Labrador and eastern Newfoundland shelves.
The three species showed distinct temperature optima in the smoothers,
consistent with their known physiology. Model uncertainty was generally
low across most of Canadian waters but elevated at the northern
(Labrador) and southern (MAB) extremes of the domain and in some coastal
sGSL areas.

**Discussion and broader relevance:** The authors emphasize that the
connectivity term, while a statistical proxy rather than an explicit
circulation model, performed comparably to much more computationally
expensive coupled biophysical approaches for capturing large-scale
transport patterns. The transboundary approach, spanning the full
US-Canada domain, provided a wider covariate range than previous
regional SDMs, which should reduce prediction uncertainty per
established SDM theory. However, the models operate at monthly
resolution and cannot capture higher-frequency transport events or local
aggregation dynamics. The SDM-based biomass climatology is framed as a
tool for identifying where and when mean prey conditions are favorable,
to be complemented by finer-scale process studies for understanding
specific foraging events. Predictions at the domain extremes,
particularly Labrador, should be interpreted cautiously given elevated
uncertainty.

**Summary of**

**Runge et al. (2025) -- Zooplankton monitoring at fixed station time
series records responses of *Calanus finmarchicus* to seasonal and
multiannual drivers in the western Gulf of Maine**

**1. Background and Motivation**

The western **Gulf of Maine (GoM)** lies at the **southern boundary of
the North Atlantic subarctic biome** and supports productive fisheries
and marine ecosystems. A key species structuring this ecosystem is the
copepod *Calanus finmarchicus*, which:

-   Dominates mesozooplankton biomass.

-   Serves as major prey for forage fish (e.g., herring, sand lance).

-   Supports higher trophic levels including the **North Atlantic right
    whale**.

Large-scale surveys such as:

-   the **Continuous Plankton Recorder (CPR)** survey

-   NOAA **EcoMon/MARMAP** programs

have documented **decadal fluctuations (\~15--20 year cycles)** in *C.
finmarchicus* abundance in the Gulf of Maine.

Around **2010**, a major **oceanographic regime shift** occurred:

-   warming of Gulf of Maine waters

-   shift from Labrador/Scotian Shelf water to warmer slope waters

-   major ecological consequences including changes in right whale
    habitat.

However, these broad surveys lack **fine temporal resolution**, making
it difficult to understand **seasonal population dynamics and
phenology**.

**Study objective**

To establish and analyze **high-frequency fixed-station time series**
that track seasonal and long-term variability in *C. finmarchicus*
abundance and community biomass.

**2. Observing System and Time-Series Design**

The study analyzes two **long-term fixed stations** in the western Gulf
of Maine.

**Wilkinson Basin Time Series (WBTS)**

-   Location: \~60 km offshore in **Wilkinson Basin**

-   Depth: \~257 m

-   Started: **2004**

-   Sampling frequency: roughly **monthly** (with some gaps)

-   Platform: UNH **R/V Gulf Challenger**

Purpose:

-   Monitor the **deep overwintering habitat** of *C. finmarchicus*

**Coastal Maine Time Series (CMTS)**

-   Location: \~8 km offshore mid-coast Maine

-   Depth: \~110 m

-   Started: **2007**

-   Sampling frequency: **semi-monthly to monthly** in summer

-   Platform: UMaine **R/V Ira C**

Purpose:

-   Represent the **Maine Coastal Current**, a productive coastal
    habitat.

**Integration with Ocean Observing Systems**

Both stations are now part of:

-   **US Marine Biodiversity Observation Network (MBON)**

-   **NERACOOS / IOOS observing system**

This embeds the stations in an operational observing framework for
**ecosystem monitoring**.

**3. Field Sampling Methods**

**Zooplankton Collection**

Sampling followed protocols similar to the **Atlantic Zone Monitoring
Program (AZMP)**.

**Net tows**

-   0.75 m ring net

-   200 μm mesh

-   Vertical tow from near-bottom to surface

-   Tow speed \~40 m min⁻¹

Samples preserved in:

-   **4% buffered formaldehyde**

Two replicate tows were taken.

**Laboratory Processing**

Samples were split using a **Folsom splitter**:

Half used for:

1.  **Biomass measurement**

2.  **Taxonomic enumeration**

**Biomass estimation**

Procedure:

1.  Filter sample on glass fiber filter or Nitex mesh

2.  Dry at **65 °C for 24--48 h**

3.  Weigh on microbalance

Result expressed as:

-   **g dry weight m⁻²** (water column integrated).

**Enumeration of *Calanus***

Subsamples were taken from the preserved material and counted under a
stereomicroscope.

Enumerated variables:

-   Copepodid stages **C1--C6**

However the main index used:

-   **C3--C6 abundance**

Reason:

-   Earlier stages escape larger-mesh nets used in other surveys (e.g.,
    EcoMon), so restricting to later stages improves comparability.

**4. Environmental Measurements**

**Hydrographic Observations**

At WBTS, CTD casts measured:

-   temperature

-   salinity

-   dissolved oxygen

-   chlorophyll fluorescence

-   light (PAR)

Instrumentation:

-   **SeaBird SBE-25Plus CTD**

-   Niskin bottle rosette.

**Chlorophyll Measurements**

Two approaches:

1.  **Fluorescence sensors** on CTD

2.  **Discrete bottle samples**

Bottle samples:

-   filtered on GF/F filters

-   stored in liquid nitrogen

-   analyzed for chlorophyll-a concentration.

Purpose:

-   quantify **phytoplankton biomass** as food supply for copepods.

**5. Population Structure Metrics**

The study quantified population stage composition using a **Copepod
Stage Index (CSI)**.

Concept:

-   weighted mean developmental stage.

Higher CSI → population dominated by older stages\
Lower CSI → younger cohort.

This metric tracks:

-   seasonal life-cycle progression

-   shifts in phenology across years.

**6. Statistical Analysis**

The time series were analyzed using **Generalized Additive Models
(GAMs)**.

These models allowed separation of:

1.  **Seasonal cycles**

2.  **Long-term trends**

The basic model included:

-   smooth function of **day of year**

-   smooth function of **year**

-   autoregressive error structure to account for temporal
    autocorrelation.

**Seasonal Life-Cycle Framework**

The authors defined four ecological seasons based on *Calanus* life
history:

  -----------------------------------------------------------------------
  **Season**       **Ecological phase**
  ---------------- ------------------------------------------------------
  Winter           Diapause C5 → adults

  Spring           New generation (C1--C4)

  Summer           Growth toward C5

  Fall             Dominant C5 diapause stage
  -----------------------------------------------------------------------

This framework allowed seasonal analysis of drivers and trends.

**Depth-Stratified Environmental Analysis**

Hydrographic trends were analyzed in three depth ranges:

-   0--50 m (surface production layer)

-   100--150 m

-   200--220 m (diapause depths)

This allowed examination of **habitat conditions during overwintering**.

**Comparison With Regional Surveys**

To validate representativeness, the WBTS data were compared with **NOAA
EcoMon survey data** using additional GAM models.

Goal:

-   determine whether the fixed station reflects **basin-scale
    dynamics**.

**7. Key Findings (Brief)**

Major observed patterns:

-   Strong seasonal cycle in *C. finmarchicus* abundance.

-   Large declines in **fall and winter abundance** after \~2010.

-   Spring production remained relatively stable.

-   Mesoplankton biomass trends mirrored *Calanus* patterns.

-   Water masses became **warmer and more saline after 2010**.

**8. Broader Relevance and Implications**

The authors argue that fixed-station monitoring provides several
important contributions.

**Ecosystem Sentinel Indicators**

Seasonal indices of:

-   *Calanus* abundance

-   stage structure

-   mesozooplankton biomass

can serve as **sentinel indicators of Gulf of Maine ecosystem health**.

**Early Detection of Climate Impacts**

Because *C. finmarchicus* is near the **southern edge of its range**,
the population may be especially sensitive to:

-   warming

-   changing water mass circulation.

Monitoring these populations can provide **early warning of ecosystem
regime shifts**.

**Forecasting and Ecosystem Applications**

The time series supports:

-   near-real-time monitoring

-   ecosystem forecasting

-   improved understanding of **food availability for right whales**

-   evaluation of **climate-driven changes in pelagic food webs**.

**9. Methodological Contributions**

The study demonstrates the value of combining:

-   **fixed-station time series**

-   **high-frequency biological sampling**

-   **hydrographic measurements**

-   **statistical modeling of phenology**

within an **ocean observing system framework (MBON/IOOS)**.

This approach complements broad surveys by providing **high temporal
resolution ecosystem indicators**.

Here is a **methods-focused structured summary** of the second paper.

**Summary of**

**Thompson et al. (2025) -- Modeling the advective supply of *Calanus
finmarchicus* to Stellwagen Bank**

Focus: **background, modeling approach, methodology, and broader
implications**

**1. Background and Motivation**

The study investigates how the copepod *Calanus finmarchicus* is
transported to **Stellwagen Bank National Marine Sanctuary (SBNMS)** in
the western Gulf of Maine.

**Ecological importance**

-   **Northern sand lance (*Ammodytes dubius*)**, a key forage fish in
    the sanctuary, feeds primarily on *C. finmarchicus*.

-   Sand lance support higher trophic levels including whales, seabirds,
    and commercially important fish.

The region lies near the **southern distribution limit** of *C.
finmarchicus*, making it sensitive to climate-driven oceanographic
changes.

**Conceptual framework: advective supply**

The study builds on the **CAST hypothesis (Coastal Amplification of
Supply and Transport)**, which proposes that:

-   *C. finmarchicus* populations in the western Gulf of Maine depend
    partly on **advection from upstream sources**.

-   Transport occurs primarily through the **Maine Coastal Current
    (MCC)**.

Thus, local abundance at Stellwagen Bank may depend not only on **local
production** but also on **physical transport from upstream regions**.

**Research objectives**

The study aimed to:

1.  Identify **source regions supplying *C. finmarchicus*** to
    Stellwagen Bank.

2.  Quantify **seasonal and interannual variability in connectivity**.

3.  Evaluate whether **upstream monitoring stations** can serve as
    indicators of downstream ecosystem conditions.

**2. Ocean Circulation Modeling Framework**

**Hydrodynamic model**

The physical ocean circulation was simulated using the **Finite Volume
Community Ocean Model (FVCOM)**.

Characteristics:

-   Unstructured-grid coastal ocean model

-   Solves **3-D primitive equations**

-   Designed for complex coastlines and bathymetry

-   High resolution in coastal regions.

The model domain covers the **Gulf of Maine and surrounding shelf
regions**.

**Model dataset**

The study used the **GoM-FVCOM hindcast simulation**:

-   Period: **1978--2016**

-   Source: **Northeast Coastal Ocean Forecast System (NECOFS)**

-   Horizontal resolution: **\~0.3--10 km**.

These simulations include realistic forcing fields from:

-   meteorological models

-   observational datasets.

The FVCOM output provided the **velocity fields used for particle
tracking experiments**.

**3. Individual-Based Particle Tracking Model**

To simulate the transport of copepods, the authors implemented an
**Individual-Based Model (IBM)** performing **Lagrangian particle
tracking**.

**Core approach**

Particles representing individual copepods were advected through the
flow field generated by FVCOM.

Key features:

-   Particle motion solved using a **fourth-order Runge--Kutta
    integration scheme**.

-   Flow fields interpolated from hourly FVCOM outputs.

-   Internal time step: **10 seconds**.

The particle model runs **offline**, meaning:

-   FVCOM simulations are generated first.

-   Stored velocity fields are then used to drive the IBM.

This reduces computational cost while preserving realistic circulation.

**Particle constraints**

Particles were tracked at **fixed depths**.

If particle depth exceeded local bathymetry:

-   it was moved to **1 m above the seabed** to prevent grounding.

**4. Numerical Experiments**

Two main classes of particle tracking experiments were conducted.

**1. Backward tracking experiments**

Purpose:

-   Identify **potential upstream source regions**.

Method:

-   Particles released **from Stellwagen Bank**.

-   Trajectories computed **backward in time**.

This determines where particles present on the bank could have
originated.

**2. Forward tracking experiments**

Purpose:

-   Evaluate how particles from upstream sources **reach Stellwagen
    Bank**.

Particles were released from several locations:

-   **CMTS** (Coastal Maine Time Series)

-   **WBTS** (Wilkinson Basin Time Series)

-   **MWRA monitoring stations**

-   Additional shelf locations.

Release areas were defined as **polygons (25--140 km²)** centered on
these sites.

**Release depths**

To represent different life stages and vertical behavior:

-   1 m

-   15 m

-   50 m

-   150 m (diapause depth).

These depths approximate:

-   surface feeding stages

-   vertically migrating stages

-   deep overwintering copepods.

**Simulation duration**

Typical tracking durations:

-   **30--60 days**

This reflects realistic transport times and developmental periods for
*C. finmarchicus*.

**5. Connectivity Analysis**

Particle trajectories generated very large datasets:

-   160 million particle positions.

To make analysis tractable, particle locations were **aggregated
spatially**.

**Spatial binning**

The region was divided into **35 ecological strata** based on NOAA's
**EcoMon survey design**.

These strata are defined using:

-   bathymetry

-   ecological similarity

-   geographic structure.

Particle positions were assigned to strata at discrete time intervals.

**Connectivity metric**

Connectivity between regions was calculated as:

**Percentage of particles from a release location found in each
stratum**

To correct for area bias:

-   percentages were **normalized by stratum area**.

This allowed comparison of relative connectivity among regions.

**6. Comparison with Observed Ocean Currents**

The authors also evaluated whether **simple observational indicators**
could approximate the modeled connectivity.

They compared the particle tracking results to **Eulerian current
measurements** from **NERACOOS buoys**:

-   B01

-   E01

-   I01.

These buoys measure currents in the **Maine Coastal Current system
upstream of Stellwagen Bank**.

**Processing of buoy data**

Steps:

1.  Hourly ADCP current measurements downloaded (2001--2022).

2.  Tidal signals removed using a **5th-order Butterworth low-pass
    filter** (23.5-hour cutoff).

3.  Alongshore current components calculated.

4.  Weekly means used as explanatory variables.

**Statistical modeling**

To test relationships between currents and connectivity:

-   **Zero-inflated negative binomial models** were fitted using the
    **glmmTMB** package.

Reason for model choice:

-   particle counts include **many zero values**

-   strong overdispersion.

Model selection was based on **AIC** and residual diagnostics.

**7. Key Results (brief)**

Major findings:

-   Stellwagen Bank is strongly connected to **upstream regions in the
    Maine Coastal Current**.

-   Connectivity peaks **spring--early summer**, coinciding with sand
    lance feeding.

-   Large **interannual variability** exists in advective supply.

-   Stronger coastal currents increase connectivity and potential
    copepod supply.

**8. Broader Implications**

**Ecosystem indicator for marine sanctuaries**

The study proposes that **upstream copepod abundance and connectivity**
could serve as indicators of ecosystem conditions at Stellwagen Bank.

Monitoring upstream populations could therefore help anticipate:

-   prey availability for sand lance

-   broader ecosystem changes.

**Climate vulnerability assessment**

Observed declines in **Maine Coastal Current speed**, linked to changing
wind patterns, may reduce copepod transport.

Reduced transport could lead to:

-   lower prey availability

-   impacts cascading through the food web.

**Decision-support and forecasting**

The framework could support predictive tools that combine:

-   particle-tracking connectivity

-   zooplankton monitoring

-   environmental indicators.

Potential applications include forecasting:

-   sand lance habitat suitability

-   whale foraging conditions

-   climate vulnerability of marine protected areas.

**9. Methodological Contribution**

The paper demonstrates an integrated approach combining:

1.  **High-resolution ocean circulation modeling (FVCOM)**

2.  **Individual-based particle tracking**

3.  **Long-term hindcasts (1978--2016)**

4.  **Connectivity metrics based on ecological survey strata**

5.  **Linkage to observational current measurements**

This approach bridges **physical oceanography, zooplankton ecology, and
ecosystem management**.
