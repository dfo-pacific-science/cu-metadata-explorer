# Data loading functions
# Fetches data dynamically from the Metadata-Questionnaire-CU-Series GitHub repo
# Data is auto-refreshed daily via GitHub Actions

#' Get raw GitHub URL for a file
#' @param path Path to file within repo
get_github_raw_url <- function(path) {
  paste0(
    "https://raw.githubusercontent.com/",
    "dfo-pacific-science/Metadata-Questionnaire-CU-Series/",
    "main/",
    path
  )
}

#' Check if cache is fresh (updated within last 24 hours)
#' @param cache_file Path to cache file
#' @param max_age_hours Maximum age in hours before considered stale (default 24)
is_cache_fresh <- function(cache_file, max_age_hours = 24) {
  if (!file.exists(cache_file)) return(FALSE)
  
  file_age <- difftime(Sys.time(), file.mtime(cache_file), units = "hours")
  as.numeric(file_age) <= max_age_hours
}

#' Load CU metadata
#' Prefers fresh cached data, falls back to GitHub API
load_cu_metadata <- function() {
  cache_file <- "data/cu_metadata_cache.csv"
  
  # Use cached data if fresh
  if (is_cache_fresh(cache_file)) {
    message("Using cached CU metadata")
    return(readr::read_csv(cache_file, show_col_types = FALSE))
  }
  
  # Try to fetch fresh data
  tryCatch({
    message("Fetching fresh CU metadata from GitHub...")
    
    # Try GitHub API first (handles auth for private repos)
    response <- httr::GET(
      "https://api.github.com/repos/dfo-pacific-science/Metadata-Questionnaire-CU-Series/contents/DATA/x_CU_Level_Metadata.csv",
      httr::add_headers(
        Accept = "application/vnd.github.v3.raw",
        Authorization = paste("Bearer", Sys.getenv("GITHUB_TOKEN"))
      )
    )
    
    if (httr::status_code(response) == 200) {
      content <- httr::content(response, as = "text", encoding = "UTF-8")
      df <- readr::read_csv(content, show_col_types = FALSE)
      
      # Update cache
      if (!dir.exists("data")) dir.create("data")
      readr::write_csv(df, cache_file)
      
      return(df)
    }
    
    # Fall back to raw URL (works for public repos)
    df <- readr::read_csv(get_github_raw_url("DATA/x_CU_Level_Metadata.csv"), show_col_types = FALSE)
    
    # Update cache
    if (!dir.exists("data")) dir.create("data")
    readr::write_csv(df, cache_file)
    
    return(df)
    
  }, error = function(e) {
    message("GitHub fetch failed, trying cache: ", e$message)
    
    # Use stale cache if available
    if (file.exists(cache_file)) {
      message("Using stale cached data")
      return(readr::read_csv(cache_file, show_col_types = FALSE))
    }
    
    stop("Could not load data from GitHub or cache")
  })
}

#' Load metadata descriptions
#' Prefers fresh cached data, falls back to GitHub API
load_metadata_descriptions <- function() {
  cache_file <- "data/descriptions_cache.csv"
  
  # Use cached data if fresh
  if (is_cache_fresh(cache_file)) {
    message("Using cached descriptions")
    return(readr::read_csv(cache_file, show_col_types = FALSE))
  }
  
  # Try to fetch fresh data
  tryCatch({
    message("Fetching fresh descriptions from GitHub...")
    
    response <- httr::GET(
      "https://api.github.com/repos/dfo-pacific-science/Metadata-Questionnaire-CU-Series/contents/DATA/x_MetadataDescriptions.csv",
      httr::add_headers(
        Accept = "application/vnd.github.v3.raw",
        Authorization = paste("Bearer", Sys.getenv("GITHUB_TOKEN"))
      )
    )
    
    if (httr::status_code(response) == 200) {
      content <- httr::content(response, as = "text", encoding = "UTF-8")
      
      # Parse the CSV, skipping comment lines
      lines <- strsplit(content, "\n")[[1]]
      data_lines <- lines[!grepl("^#", lines)]
      clean_content <- paste(data_lines, collapse = "\n")
      
      df <- readr::read_csv(clean_content, show_col_types = FALSE)
      
      # Update cache
      if (!dir.exists("data")) dir.create("data")
      readr::write_csv(df, cache_file)
      
      return(df)
    }
    
    # Fall back to raw URL
    content <- readr::read_file(get_github_raw_url("DATA/x_MetadataDescriptions.csv"))
    lines <- strsplit(content, "\n")[[1]]
    data_lines <- lines[!grepl("^#", lines)]
    clean_content <- paste(data_lines, collapse = "\n")
    
    df <- readr::read_csv(clean_content, show_col_types = FALSE)
    
    # Update cache
    if (!dir.exists("data")) dir.create("data")
    readr::write_csv(df, cache_file)
    
    return(df)
    
  }, error = function(e) {
    message("GitHub fetch failed, trying cache: ", e$message)
    
    if (file.exists(cache_file)) {
      message("Using stale cached descriptions")
      return(readr::read_csv(cache_file, show_col_types = FALSE))
    }
    
    stop("Could not load descriptions from GitHub or cache")
  })
}

#' Get last refresh time from GitHub Actions
get_last_refresh_time <- function() {
  timestamp_file <- "data/last_refresh.txt"
  if (file.exists(timestamp_file)) {
    return(readLines(timestamp_file, n = 1))
  }
  return(NULL)
}
