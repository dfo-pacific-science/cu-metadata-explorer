# CU Metadata Explorer
# Interactive Shiny app for exploring CU-level metadata from WSP status assessments

library(shiny)
library(bslib)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)
library(plotly)
library(readr)
library(httr)
library(jsonlite)

# Source helper functions
source("R/data_loader.R")
source("R/utils.R")

# UI ----
ui <- page_navbar(
  title = "CU Metadata Explorer",
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2c3e50"
  ),
  
  # Tab 1: Data Explorer
  nav_panel(
    title = "Data Explorer",
    icon = icon("table"),
    layout_sidebar(
      sidebar = sidebar(
        title = "Filters",
        width = 300,
        selectInput(
          "species_filter",
          "Species",
          choices = NULL,
          multiple = TRUE
        ),
        selectInput(
          "region_filter",
          "DFO Region",
          choices = NULL,
          multiple = TRUE
        ),
        selectInput(
          "verification_filter",
          "CU Verification",
          choices = NULL,
          multiple = TRUE
        ),
        selectInput(
          "assessment_stage_filter",
          "Assessment Stage",
          choices = NULL,
          multiple = TRUE
        ),
        hr(),
        selectInput(
          "column_select",
          "Columns to Display",
          choices = NULL,
          multiple = TRUE,
          selected = NULL
        ),
        actionButton("reset_filters", "Reset Filters", class = "btn-secondary"),
        hr(),
        p(class = "text-muted small", 
          textOutput("data_update_time"))
      ),
      card(
        card_header("CU Metadata Table"),
        DTOutput("metadata_table"),
        card_footer(
          textOutput("row_count")
        )
      )
    )
  ),
  
  # Tab 2: Visualizations
  nav_panel(
    title = "Visualizations",
    icon = icon("chart-bar"),
    layout_sidebar(
      sidebar = sidebar(
        title = "Chart Options",
        width = 280,
        selectInput(
          "viz_primary",
          "Primary Variable",
          choices = c(
            "Species" = "Species",
            "DFO Region" = "DFORegion",
            "CU Verification" = "CU_Verification",
            "Assessment Stage" = "StatusProcess_AssessmentStage",
            "Spawner Est Type" = "Spn_EstType",
            "Life History Type" = "LifeHistoryType_General",
            "Cyclic Pattern" = "Cyclic"
          )
        ),
        selectInput(
          "viz_secondary",
          "Group By (optional)",
          choices = c(
            "None" = "none",
            "Species" = "Species",
            "DFO Region" = "DFORegion",
            "CU Verification" = "CU_Verification",
            "Assessment Stage" = "StatusProcess_AssessmentStage"
          )
        ),
        checkboxInput("viz_pct", "Show as Percentage", FALSE),
        hr(),
        p(class = "text-muted", "Visualizations update based on filtered data from the Data Explorer tab.")
      ),
      layout_columns(
        col_widths = c(6, 6, 12),
        card(
          card_header("Distribution"),
          plotlyOutput("bar_chart", height = "350px")
        ),
        card(
          card_header("Summary Statistics"),
          verbatimTextOutput("summary_stats")
        ),
        card(
          card_header("Crosstab"),
          DTOutput("crosstab_table")
        )
      )
    )
  ),
  
  # Tab 3: Column Definitions
  nav_panel(
    title = "Column Definitions",
    icon = icon("book"),
    layout_sidebar(
      sidebar = sidebar(
        title = "Filter Definitions",
        width = 280,
        selectInput(
          "def_topic_filter",
          "Topic",
          choices = NULL,
          multiple = TRUE
        ),
        textInput(
          "def_search",
          "Search",
          placeholder = "Search variable names or descriptions..."
        )
      ),
      layout_columns(
        col_widths = 12,
        card(
          card_header("Metadata Variable Definitions"),
          DTOutput("definitions_table")
        ),
        card(
          card_header("Unique Values for Selected Column"),
          selectInput(
            "value_preview_col",
            "Select Column to Preview Values",
            choices = NULL
          ),
          verbatimTextOutput("unique_values")
        )
      )
    )
  ),
  
  # Tab 4: About
  nav_panel(
    title = "About",
    icon = icon("info-circle"),
    card(
      card_header("About This App"),
      card_body(
        markdown("
## CU Metadata Explorer

This app provides an interactive interface for exploring Conservation Unit (CU) level metadata from Wild Salmon Policy (WSP) status assessments.

### Data Source

Data is loaded dynamically from the [Metadata-Questionnaire-CU-Series](https://github.com/dfo-pacific-science/Metadata-Questionnaire-CU-Series) repository. The app checks for updates each time it loads.

### Key Files

- **x_CU_Level_Metadata.csv**: The main metadata file containing information about each CU
- **x_MetadataDescriptions.csv**: Descriptions and definitions for each metadata column

### Tabs

1. **Data Explorer**: Browse and filter the complete metadata table
2. **Visualizations**: Interactive charts summarizing the data
3. **Column Definitions**: Reference for what each column means and acceptable values

### Contact

For questions about this app or the underlying data, contact the Data Stewardship Unit at DFO Pacific Region.
        ")
      )
    )
  ),
  
  nav_spacer(),
  nav_item(
    actionButton("refresh_data", "Refresh Data", icon = icon("sync"), class = "btn-sm btn-outline-light")
  )
)

# Server ----
server <- function(input, output, session) {
  
  # Reactive values for data
  rv <- reactiveValues(
    metadata = NULL,
    descriptions = NULL,
    last_update = NULL
  )
  
  # Load data on startup and refresh
  load_all_data <- function() {
    withProgress(message = "Loading data from GitHub...", {
      rv$metadata <- load_cu_metadata()
      incProgress(0.5)
      rv$descriptions <- load_metadata_descriptions()
      incProgress(0.5)
      rv$last_update <- Sys.time()
    })
  }
  
  # Initial load
  observe({
    load_all_data()
  }, priority = 100)
  
  # Refresh button
  observeEvent(input$refresh_data, {
    load_all_data()
    showNotification("Data refreshed!", type = "message")
  })
  
  # Update filter choices when data loads
  observe({
    req(rv$metadata)
    
    df <- rv$metadata
    
    updateSelectInput(session, "species_filter",
                      choices = c("All" = "", sort(unique(na.omit(df$Species)))))
    updateSelectInput(session, "region_filter",
                      choices = c("All" = "", sort(unique(na.omit(df$DFORegion)))))
    updateSelectInput(session, "verification_filter",
                      choices = c("All" = "", sort(unique(na.omit(df$CU_Verification)))))
    updateSelectInput(session, "assessment_stage_filter",
                      choices = c("All" = "", sort(unique(na.omit(df$StatusProcess_AssessmentStage)))))
    
    # Default columns for display
    default_cols <- c("CU_ID", "CU_Name", "Species", "DFORegion", 
                      "CU_Verification", "StatusProcess_AssessmentStage",
                      "Spn_EstType", "LifeHistoryType_General")
    
    updateSelectInput(session, "column_select",
                      choices = names(df),
                      selected = intersect(default_cols, names(df)))
    
    updateSelectInput(session, "value_preview_col",
                      choices = names(df))
  })
  
  # Update definition filters
  observe({
    req(rv$descriptions)
    topics <- unique(na.omit(rv$descriptions$Topic))
    updateSelectInput(session, "def_topic_filter",
                      choices = c("All" = "", sort(topics)))
  })
  
  # Filtered data
  filtered_data <- reactive({
    req(rv$metadata)
    df <- rv$metadata
    
    if (length(input$species_filter) > 0 && !("" %in% input$species_filter)) {
      df <- df %>% filter(Species %in% input$species_filter)
    }
    if (length(input$region_filter) > 0 && !("" %in% input$region_filter)) {
      df <- df %>% filter(DFORegion %in% input$region_filter)
    }
    if (length(input$verification_filter) > 0 && !("" %in% input$verification_filter)) {
      df <- df %>% filter(CU_Verification %in% input$verification_filter)
    }
    if (length(input$assessment_stage_filter) > 0 && !("" %in% input$assessment_stage_filter)) {
      df <- df %>% filter(StatusProcess_AssessmentStage %in% input$assessment_stage_filter)
    }
    
    df
  })
  
  # Reset filters
  observeEvent(input$reset_filters, {
    updateSelectInput(session, "species_filter", selected = "")
    updateSelectInput(session, "region_filter", selected = "")
    updateSelectInput(session, "verification_filter", selected = "")
    updateSelectInput(session, "assessment_stage_filter", selected = "")
  })
  
  # Data update time
  output$data_update_time <- renderText({
    req(rv$last_update)
    paste("Last updated:", format(rv$last_update, "%Y-%m-%d %H:%M"))
  })
  
  # Main data table
  output$metadata_table <- renderDT({
    req(filtered_data())
    
    cols <- if (length(input$column_select) > 0) input$column_select else names(filtered_data())[1:8]
    
    filtered_data() %>%
      select(any_of(cols)) %>%
      datatable(
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel')
        ),
        filter = "top",
        rownames = FALSE,
        extensions = 'Buttons'
      )
  })
  
  # Row count
  output$row_count <- renderText({
    req(filtered_data(), rv$metadata)
    paste0("Showing ", nrow(filtered_data()), " of ", nrow(rv$metadata), " CUs")
  })
  
  # Bar chart visualization
  output$bar_chart <- renderPlotly({
    req(filtered_data(), input$viz_primary)
    
    df <- filtered_data()
    primary_var <- input$viz_primary
    secondary_var <- input$viz_secondary
    
    if (secondary_var == "none" || secondary_var == primary_var) {
      # Simple bar chart
      plot_df <- df %>%
        count(!!sym(primary_var)) %>%
        mutate(pct = n / sum(n) * 100)
      
      if (input$viz_pct) {
        p <- ggplot(plot_df, aes(x = reorder(!!sym(primary_var), -pct), y = pct)) +
          geom_col(fill = "#2c3e50") +
          labs(x = primary_var, y = "Percentage") +
          theme_minimal()
      } else {
        p <- ggplot(plot_df, aes(x = reorder(!!sym(primary_var), -n), y = n)) +
          geom_col(fill = "#2c3e50") +
          labs(x = primary_var, y = "Count") +
          theme_minimal()
      }
    } else {
      # Grouped bar chart
      plot_df <- df %>%
        count(!!sym(primary_var), !!sym(secondary_var))
      
      if (input$viz_pct) {
        plot_df <- plot_df %>%
          group_by(!!sym(primary_var)) %>%
          mutate(pct = n / sum(n) * 100)
        
        p <- ggplot(plot_df, aes(x = !!sym(primary_var), y = pct, fill = !!sym(secondary_var))) +
          geom_col(position = "dodge") +
          labs(x = primary_var, y = "Percentage") +
          theme_minimal()
      } else {
        p <- ggplot(plot_df, aes(x = !!sym(primary_var), y = n, fill = !!sym(secondary_var))) +
          geom_col(position = "dodge") +
          labs(x = primary_var, y = "Count") +
          theme_minimal()
      }
    }
    
    ggplotly(p)
  })
  
  # Summary statistics
  output$summary_stats <- renderPrint({
    req(filtered_data())
    df <- filtered_data()
    
    cat("=== Data Summary ===\n\n")
    cat("Total CUs:", nrow(df), "\n\n")
    cat("By Species:\n")
    print(table(df$Species, useNA = "ifany"))
    cat("\nBy Region:\n")
    print(table(df$DFORegion, useNA = "ifany"))
  })
  
  # Crosstab table
  output$crosstab_table <- renderDT({
    req(filtered_data(), input$viz_primary, input$viz_secondary)
    
    if (input$viz_secondary == "none") {
      # Simple frequency table
      filtered_data() %>%
        count(!!sym(input$viz_primary), name = "Count") %>%
        arrange(desc(Count)) %>%
        datatable(options = list(pageLength = 10, dom = 't'), rownames = FALSE)
    } else {
      # Cross-tabulation
      filtered_data() %>%
        count(!!sym(input$viz_primary), !!sym(input$viz_secondary)) %>%
        pivot_wider(names_from = !!sym(input$viz_secondary), values_from = n, values_fill = 0) %>%
        datatable(options = list(pageLength = 10, scrollX = TRUE, dom = 't'), rownames = FALSE)
    }
  })
  
  # Filtered definitions
  filtered_definitions <- reactive({
    req(rv$descriptions)
    df <- rv$descriptions
    
    if (length(input$def_topic_filter) > 0 && !("" %in% input$def_topic_filter)) {
      df <- df %>% filter(Topic %in% input$def_topic_filter)
    }
    
    if (nzchar(input$def_search)) {
      search_term <- tolower(input$def_search)
      df <- df %>%
        filter(
          grepl(search_term, tolower(Variable), fixed = TRUE) |
          grepl(search_term, tolower(Description), fixed = TRUE)
        )
    }
    
    df
  })
  
  # Definitions table
  output$definitions_table <- renderDT({
    req(filtered_definitions())
    
    filtered_definitions() %>%
      select(Level, Topic, Variable, Description, OtherNotes) %>%
      datatable(
        options = list(
          pageLength = 20,
          scrollX = TRUE,
          dom = 'frtip'
        ),
        rownames = FALSE,
        filter = "top"
      )
  })
  
  # Unique values preview
  output$unique_values <- renderPrint({
    req(rv$metadata, input$value_preview_col)
    
    col_data <- rv$metadata[[input$value_preview_col]]
    unique_vals <- sort(unique(na.omit(col_data)))
    
    cat("Column:", input$value_preview_col, "\n")
    cat("Total values:", length(col_data), "\n")
    cat("Unique values:", length(unique_vals), "\n")
    cat("Missing values:", sum(is.na(col_data)), "\n\n")
    
    if (length(unique_vals) <= 50) {
      cat("Values:\n")
      for (v in unique_vals) {
        count <- sum(col_data == v, na.rm = TRUE)
        cat(sprintf("  %s (%d)\n", v, count))
      }
    } else {
      cat("Too many unique values to display (showing first 30):\n")
      for (v in unique_vals[1:30]) {
        count <- sum(col_data == v, na.rm = TRUE)
        cat(sprintf("  %s (%d)\n", v, count))
      }
      cat(sprintf("  ... and %d more\n", length(unique_vals) - 30))
    }
  })
}

# Run the app
shinyApp(ui, server)
