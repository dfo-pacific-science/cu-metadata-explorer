# CU Metadata Explorer

An interactive Shiny application for exploring Conservation Unit (CU) level metadata from Wild Salmon Policy (WSP) status assessments.

## Features

- **Data Explorer**: Browse and filter the complete CU metadata table with customizable column selection
- **Visualizations**: Interactive charts summarizing data by species, region, verification status, and more
- **Column Definitions**: Reference documentation for all metadata fields with acceptable values
- **Live Data**: Automatically fetches the latest data from the source repository

## Data Source

This app loads data from the [Metadata-Questionnaire-CU-Series](https://github.com/dfo-pacific-science/Metadata-Questionnaire-CU-Series) repository:

- `DATA/x_CU_Level_Metadata.csv` - Main metadata table with ~103 columns describing each CU
- `DATA/x_MetadataDescriptions.csv` - Column definitions and documentation

For reliability, the repo includes cached copies in `data/`:

- `data/cu_metadata_cache.csv`
- `data/descriptions_cache.csv`
- `data/last_refresh.txt`

At runtime, the app tries GitHub first and falls back to local cache if needed.

## Running Locally

### Prerequisites

- R (>= 4.0)
- Required packages (install with `install.packages()`):
  - shiny
  - bslib
  - DT
  - dplyr
  - tidyr
  - ggplot2
  - plotly
  - readr
  - httr
  - jsonlite

### Quick Start

```bash
# Clone the repository
git clone https://github.com/dfo-pacific-science/cu-metadata-explorer.git
cd cu-metadata-explorer

# Optional: refresh local cache from source data
./update-agent.sh
```

```r
# Open R in the project directory and run:
shiny::runApp()
```

### GitHub Authentication (for private repos)

If the source data repository is private, set your GitHub token:

```r
Sys.setenv(GITHUB_TOKEN = "your_github_pat_here")
```

Or add to your `.Renviron` file:
```
GITHUB_TOKEN=your_github_pat_here
```

## Deployment

### shinyapps.io

```r
rsconnect::deployApp()
```

### Posit Connect / Shiny Server

Deploy as standard Shiny app. Ensure the server has network access to GitHub API.

## Project Structure

```
cu-metadata-explorer/
├── app.R                 # Main Shiny application
├── R/
│   ├── data_loader.R     # GitHub data fetching with caching
│   └── utils.R           # Helper functions
├── data/                 # Cached data committed for runtime fallback
├── update-agent.sh       # Manual cache refresh helper
├── README.md
└── .gitignore
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is part of DFO's Data Stewardship Unit work. Contact the team for licensing details.

## Contact

Data Stewardship Unit  
DFO Pacific Region
