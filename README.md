# Lebanon Mobility Intelligence

This project uses the Tari'ak crowdsourced traffic dataset to identify recurring patterns in observed road movement across Lebanon. The main goal is to discover candidate mobility bottlenecks: road segments and time windows that repeatedly show low or unstable observed velocity.

The project is developed as an **AI for Lebanon** project for the LebNet Tech Fellows program. It is a historical mobility-intelligence prototype, not a live traffic-control or accident-prediction system.

## Project Motivation

Poor transport connectivity and congestion affect commuting time, access to services, productivity, and mobility in Lebanon. However, publicly available Lebanese traffic data is limited, especially data that is detailed, geolocated, and available across time.

This project asks:

> Can crowdsourced movement observations be transformed into useful evidence about where and when recurring mobility problems appear?

The intended users are transportation researchers, municipalities, public-transport planners, and mobility or logistics companies. The output can help identify locations and time windows that deserve further investigation, better data collection, or planning attention.

## Dataset

The project uses the [Tari'ak Lebanon Traffic Dataset](https://github.com/ramikay/lebanon-traffic-dataset), which contains smartphone-generated movement observations map-matched to OpenStreetMap street identifiers.

The dataset is provided by [Tari'ak](http://tari2ak.com/) and licensed under the [Open Data Commons Open Database License (ODbL v1.0)](https://opendatacommons.org/licenses/odbl/1-0/). It is used here under the terms of that license, which requires attribution to tari2ak.com and specifies that any publicly shared or redistributed derived database remains under compatible open terms.

Each row represents one observation containing:

* `Date` and `Time` of collection
* `Coordinate (Lon, Lat)` of the device
* `Course`, or direction of travel in degrees
* `Velocity`, documented by the source as meters per second
* `OSM ID`, the matched OpenStreetMap street identifier

The raw file is not included in this repository because of its size. To reproduce the project, place `velocities.txt` inside:

```text
data/raw/
```

Generated processed files and the SQLite database remain local and are excluded from version control.

## Feasibility Results

Notebook 00 found:

* 6,006,401 observations
* 1,673 consecutive dates from March 20, 2015 through October 17, 2019
* 14,289 unique mapped street identifiers
* No missing values in the six raw columns
* No invalid timestamps or coordinate ranges found in the full scan
* No exact duplicate records found in the full-dataset check
* Repeated observations across both road segments and time, enabling segment-level profiles

The data is suitable for historical pattern discovery and candidate-bottleneck analysis. It is not sufficient on its own to prove that a road is congested or to explain why its velocity changes.

## Project Structure

```text
lebanon-traffic-ml/
├── data/
│   ├── raw/                         # Downloaded source data, not tracked by Git
│   └── processed/                   # Generated CSV and SQLite database, not tracked by Git
├── notebooks/
│   ├── 00_dataset_feasibility.ipynb
│   ├── 01_sql_traffic_analysis.ipynb
│   ├── 02_machine_learning.ipynb
│   └── 03_visualizations_and_insights.ipynb
├── reports/
│   └── figures/                     # Exported final visualizations
├── sql/
│   └── traffic_analysis.sql
├── README.md
├── requirements.txt
└── LICENSE
```

## Notebook Summary

### 00_dataset_feasibility.ipynb

Completed. This notebook establishes the row grain, parses timestamps and coordinates, checks raw validity, measures coverage, checks duplicates, summarizes road-segment and hourly structure, documents the project's scope, and exports cleaned analysis data.

### 01_sql_traffic_analysis.ipynb

In progress. This notebook loads the processed data into SQLite and builds the evidence base: observation coverage, hourly patterns, road-segment frequency, segment-level velocity profiles, and candidate recurring bottlenecks.

### 02_machine_learning.ipynb

Planned. This notebook will use unsupervised learning to group road segments by recurring movement behavior. A velocity-estimation model may be included as a supporting experiment for sparse segment-time combinations, evaluated against transparent baselines.

### 03_visualizations_and_insights.ipynb

Planned. This notebook will present the strongest supported findings through maps, rankings, temporal comparisons, cluster summaries, and an explanation of practical use cases and limitations.

## Planned Approach

1. Aggregate observations by road segment and time period.
2. Calculate average or median velocity, variation, observation count, and low-velocity frequency.
3. Identify segments with recurring slow or unstable patterns while filtering out poorly observed segments.
4. Cluster segments by their temporal movement profiles.
5. Present candidate bottlenecks and confidence indicators in a visual report.

The machine-learning component supports pattern discovery; it is not presented as a system that solves congestion or predicts accidents.

## Practical Value

The resulting tool could help:

* Municipalities and transport planners prioritize locations for investigation or future data collection.
* Public-transport planners compare corridors and time windows where mobility is repeatedly slow.
* Logistics and fleet operators identify historically unreliable corridors as one input into planning.
* Researchers and NGOs build a baseline for mobility analysis in a data-limited environment.

These are decision-support use cases. The project does not claim that the analysis alone can justify infrastructure investment or prove the cause of a slowdown.

## Limitations

The data is historical, crowdsourced, and not a complete census of traffic. It does not include vehicle identifiers, traffic volume, road capacity, speed limits, route context, weather, incidents, public-transport routes, or current real-time observations. Sampling may be uneven across locations and times.

The project therefore cannot reliably claim to measure live congestion, accidents, travel time, emissions, or causal effects. The results should be interpreted as candidate historical patterns that require validation with better and newer data.

## Tools Used

* Python
* Pandas
* NumPy
* SQLite
* Matplotlib
* Seaborn
* Scikit-learn
* Jupyter Notebook
* Git and GitHub

## License

The source code and analytical notebooks in this repository are licensed under the [MIT License](LICENSE).

The underlying Tari'ak traffic dataset and any derived data artifacts generated from it remain subject to the [Open Data Commons Open Database License (ODbL v1.0)](https://opendatacommons.org/licenses/odbl/1-0/) by [Tari'ak](http://tari2ak.com/).

Thank you for checking this project out! :)
