# Data loading functions
# Fetches data dynamically from the Metadata-Questionnaire-CU-Series GitHub repo

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

#' Load CU metadata from GitHub
#' Falls back to cached data if GitHub is unavailable
load_cu_metadata <- function() {
  url <- get_github_raw_url("DATA/x_CU_Level_Metadata.csv")
  cache_file <- "data/cu_metadata_cache.csv"
  
  tryCatch({
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
      
      # Cache the data
      if (!dir.exists("data")) dir.create("data")
      readr::write_csv(df, cache_file)
      
      return(df)
    }
    
    # Fall back to raw URL (works for public repos)
    df <- readr::read_csv(url, show_col_types = FALSE)
    
    # Cache the data
    if (!dir.exists("data")) dir.create("data")
    readr::write_csv(df, cache_file)
    
    return(df)
    
  }, error = function(e) {
    message("GitHub fetch failed, trying cache: ", e$message)
    
    # Try to use cached data
    if (file.exists(cache_file)) {
      message("Using cached data")
      return(readr::read_csv(cache_file, show_col_types = FALSE))
    }
    
    stop("Could not load data from GitHub or cache")
  })
}

#' Load metadata descriptions from GitHub
#' Falls back to cached data if GitHub is unavailable
load_metadata_descriptions <- function() {
  cache_file <- "data/descriptions_cache.csv"
  
  tryCatch({
    # Try GitHub API first
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
      
      # Cache the data
      if (!dir.exists("data")) dir.create("data")
      readr::write_csv(df, cache_file)
      
      return(df)
    }
    
    # Fall back to raw URL
    url <- get_github_raw_url("DATA/x_MetadataDescriptions.csv")
    content <- readr::read_file(url)
    
    # Parse, skipping comment lines
    lines <- strsplit(content, "\n")[[1]]
    data_lines <- lines[!grepl("^#", lines)]
    clean_content <- paste(data_lines, collapse = "\n")
    
    df <- readr::read_csv(clean_content, show_col_types = FALSE)
    
    # Cache
    if (!dir.exists("data")) dir.create("data")
    readr::write_csv(df, cache_file)
    
    return(df)
    
  }, error = function(e) {
    message("GitHub fetch failed, trying cache: ", e$message)
    
    if (file.exists(cache_file)) {
      message("Using cached descriptions")
      return(readr::read_csv(cache_file, show_col_types = FALSE))
    }
    
    stop("Could not load descriptions from GitHub or cache")
  })
}

#' Check if data is stale (older than X hours)
#' @param cache_file Path to cache file
#' @param max_age_hours Maximum age in hours before considered stale
is_cache_stale <- function(cache_file, max_age_hours = 24) {
  if (!file.exists(cache_file)) return(TRUE)
  
  file_age <- difftime(Sys.time(), file.mtime(cache_file), units = "hours")
  as.numeric(file_age) > max_age_hours
}
