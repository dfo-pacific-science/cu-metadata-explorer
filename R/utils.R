# Utility functions for CU Metadata Explorer

#' Clean column names for display
#' Converts snake_case to Title Case with spaces
clean_column_name <- function(x) {
  x <- gsub("_", " ", x)
  x <- tools::toTitleCase(x)
  x
}

#' Get summary of categorical variable
#' @param df Data frame
#' @param col Column name
summarize_categorical <- function(df, col) {
  if (!col %in% names(df)) return(NULL)
  
  counts <- table(df[[col]], useNA = "ifany")
  data.frame(
    Value = names(counts),
    Count = as.vector(counts),
    Percent = round(as.vector(counts) / sum(counts) * 100, 1)
  ) %>%
    arrange(desc(Count))
}

#' Create a contingency table
#' @param df Data frame
#' @param row_var Row variable
#' @param col_var Column variable
create_contingency <- function(df, row_var, col_var) {
  if (!row_var %in% names(df) || !col_var %in% names(df)) return(NULL)
  
  table(df[[row_var]], df[[col_var]], useNA = "ifany")
}

#' Format percentage
fmt_pct <- function(x, digits = 1) {
  paste0(round(x, digits), "%")
}

#' Get column type info
#' @param df Data frame
#' @param col Column name
get_column_info <- function(df, col) {
  if (!col %in% names(df)) return(NULL)
  
  data <- df[[col]]
  n_unique <- length(unique(na.omit(data)))
  n_missing <- sum(is.na(data))
  
  list(
    name = col,
    type = class(data)[1],
    n_unique = n_unique,
    n_missing = n_missing,
    pct_missing = round(n_missing / length(data) * 100, 1),
    is_categorical = n_unique <= 20 || is.character(data) || is.factor(data)
  )
}

#' Suggest visualization type based on column
suggest_viz <- function(df, col) {
  info <- get_column_info(df, col)
  if (is.null(info)) return("none")
  
  if (info$is_categorical) {
    if (info$n_unique <= 10) return("bar")
    return("table")
  }
  
  if (is.numeric(df[[col]])) {
    return("histogram")
  }
  
  "table"
}
