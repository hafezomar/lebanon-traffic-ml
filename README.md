# Lebanon Road Velocity Analysis and Estimation

This project analyzes road-velocity observations in Lebanon using the Tari'ak crowdsourced traffic dataset. It examines when and where observed velocities vary, then evaluates whether time, location, direction, and road-segment information can support a useful machine-learning model for estimating recorded velocity.

The project is developed as an **AI for Lebanon** project for the LebNet Tech Fellows program. It focuses on a practical local mobility dataset while being careful about what the available data can and cannot establish.

## Project Motivation

Traffic conditions affect everyday mobility, time use, and access to services. This project uses a large public dataset of observed road velocities to explore temporal and spatial variation in Lebanon and to test a focused predictive task: estimating the velocity recorded for a road observation.

The goal is not to claim that the dataset alone measures congestion, travel time, incidents, or the performance of Lebanon's road network. Instead, the project asks a narrower, testable question:

> Given the observation time, location, direction, and mapped road segment, how well can a model estimate the velocity recorded in this dataset?

This framing keeps the analysis useful while respecting the limits of crowdsourced observational data.

## Dataset

The project uses the [Tari'ak Lebanon Traffic Dataset](https://github.com/ramikay/lebanon-traffic-dataset).

The raw file contains timestamped traffic observations with the following fields:

* `Date` and `Time`
* `Coordinate (Lon, Lat)`
* `Course`
* `Velocity`
* `OSM ID`

The raw dataset is not included in this repository because of its size. To reproduce the project, place the downloaded `velocities.txt` file in:

```text
data/raw/
```

The processed CSV and SQLite database are generated locally and are also excluded from version control.

## Dataset Feasibility Results

Notebook 00 confirmed that the raw dataset is structurally suitable for analysis:

* 6,006,401 observations
* Continuous daily coverage from March 20, 2015 through October 17, 2019 (1,673 dates)
* 14,289 unique OpenStreetMap road-segment identifiers
* No missing values in the six raw columns
* No invalid timestamps or coordinates found during the full scan
* No exact duplicate records found during the full-dataset check
* A continuous `Velocity` field ranging from 0 to approximately 120, with a mean of 44.982

Velocity varies across hours and road segments, which provides enough repeated temporal and spatial structure to evaluate an observed-velocity estimation task. The unit and collection semantics of `Velocity` remain unverified, so the analysis avoids labeling it as km/h unless the source documentation confirms that interpretation.

## Project Structure

```text
lebanon-traffic-ml/
├── data/
│   ├── raw/                         # Downloaded Tari'ak source data, not tracked by Git
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

Completed. This notebook establishes the row structure, parses timestamps and coordinates, checks missingness and validity, measures temporal coverage, checks full-dataset duplicates, summarizes road-segment and hourly structure, and exports a clean modeling dataset.

The processed output adds reusable fields including `timestamp`, `year`, `month`, `day_of_week`, `hour`, `longitude`, `latitude`, `course`, `velocity`, and `osm_id`.

### 01_sql_traffic_analysis.ipynb

In progress. This notebook loads the processed data into SQLite and will answer focused SQL questions about hourly patterns, weekday and weekend differences, repeated road segments, low observed-velocity segments, and monthly trends.

### 02_machine_learning.ipynb

Planned. This notebook will evaluate chronological machine-learning baselines for estimating observed velocity. Candidate features include time-of-day, calendar variables, coordinates, course, and road-segment identifiers.

The evaluation will use chronological train, validation, and test splits. A random split would risk leakage because the same segments are observed repeatedly over time.

### 03_visualizations_and_insights.ipynb

Planned. This notebook will present the strongest supported temporal, spatial, and modeling findings with clear limitations and reproducible figures.

## Planned Modeling Approach

The proposed target is `velocity`.

The first model comparisons will include simple baselines such as the overall mean, hour-of-day mean, and road-segment mean. Machine-learning models will only be considered useful if they improve meaningfully over those baselines on unseen future observations.

Candidate evaluation metrics include MAE and RMSE. Results will be reported alongside the baseline performance, not as isolated model scores.

## Limitations

The dataset does not include vehicle identifiers, road capacity, speed limits, route context, weather, incidents, or a verified velocity unit. It also represents recorded crowdsourced observations rather than a complete census of all traffic in Lebanon.

As a result, the project will describe observed patterns and model-estimation performance carefully. It will not make causal claims about why velocity changes or present the model as a real-time routing or congestion system.

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

This project is licensed under the MIT License. The Tari'ak dataset remains subject to its original terms and ownership.
