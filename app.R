# Load packages -----------------------------------------------------
library(shiny)
library(tidyverse)
library(DT)
library(glue)
library(lubridate)
library(shinythemes)

# Load data ---------------------------------------------------------
jsm_sessions <- read_csv("app-data/jsm2019_sessions.csv")
jsm_talks <- read_csv("app-data/jsm2019_talks.csv")

# Create lists for use later ----------------------------------------
sponsors <- glue_collapse(jsm_sessions$sponsor, sep = ", ") %>%
  str_split(", ") %>%
  purrr::pluck(1) %>%
  str_trim() %>%
  unique() %>%
  sort()

types <- jsm_sessions %>%
  distinct(type) %>%
  arrange() %>%
  pull()

types <- c(
  keep(types, str_detect, pattern = "^Invited") %>% sort(),
  keep(types, str_detect, pattern = "^Topic") %>% sort(),
  keep(types, str_detect, pattern = "^Contributed") %>% sort(),
  discard(types, str_detect, pattern = "^Invited|^Topic|^Contributed|^Other") %>% sort(),
  "Other"
)

# Set conf start date -----------------------------------------------
conf_start <- "2019-07-26"

# UI ----------------------------------------------------------------
ui <- navbarPage(
  theme = shinytheme("cosmo"),
  "JSM 2019",
  
  # Tab 1: Session schedule -----------------------------------------
  tabPanel("Session Schedule",
           sidebarLayout(
             sidebarPanel(
               # Instructions ---------------------------------------
               h4("Select date/time, sponsors, and type of session."),
               br(),
               
               # Select day(s) --------------------------------------
               checkboxGroupInput(
                 "day",
                 "Day",
                 choices = c(
                   "Fri, Jul 26" = "Fri",
                   "Sat, Jul 27" = "Sat",
                   "Sun, Jul 28" = "Sun",
                   "Mon, Jul 29" = "Mon",
                   "Tue, Jul 30" = "Tue",
                   "Wed, Jul 31"  = "Wed",
                   "Thu, Aug 1"  = "Thu"
                 ),
                 # 
                 selected = ifelse(Sys.Date() < conf_start, 
                                   "Sun", 
                                   as.character(wday(Sys.Date(), label = TRUE, abbr = TRUE)))
               ),
               
               # Select times ---------------------------------------
               sliderInput(
                 "time",
                 "Time",
                 min = 7,
                 max = 23,
                 value = c(8, 18),
                 step = 1
               ),
               
               # Select sponsor(s) ----------------------------------
               selectInput(
                 "sponsor",
                 "Session sponsor",
                 choices = sponsors,
                 selected = c(
                   "Section on Statistics and Data Science Education",
                   "Section on Statistical Computing",
                   "Section on Statistical Graphics"
                 ),
                 multiple = TRUE,
                 selectize = TRUE
               ),
               
               # Select typess ------------------------------------
               selectInput(
                 "type",
                 "Session type",
                 choices = types,
                 multiple = TRUE,
                 selectize = TRUE
               ),
               
               # Filter by session title ----------------------------------------------
               textInput(
                 "session_keyword_text",
                 "Keywords or phrases in session title, separated by commas"
               ),
               
               br(),
               
               
               # Excluded fee events --------------------------------
               checkboxInput("exclude_fee",
                             "Exclude added fee events"),
               
               br(),
               hr(),
               br(),
               
               # Footnote -------------------------------------------
               HTML('For the official JSM 2019 website, including conference information, registration for short courses, and an online program with more customization options, visit <a href="https://ww2.amstat.org/meetings/jsm/2019/onlineprogram/index.cfm">here</a>.'),
               
               width = 3
               
             ),
             
             # Output -----------------------------------------------
             mainPanel(DT::dataTableOutput(outputId = "schedule"), width = 9)
             
           )),
  
  # Tab 2: Talk finder
  tabPanel("Talk Finder",
           sidebarLayout(
             sidebarPanel(
               # Instructions ---------------------------------------
               h4("Search for keywords or phrases in session titles."),
               br(),
               
               # Keyword selection ----------------------------------
               checkboxGroupInput(
                 "keyword_choice",
                 "Select keywords you're interested in",
                 choices = c(
                   "R"       = "( R | R$)",
                   "tidy"    = "tidy",
                   "Shiny"   = "shiny",
                   "RStudio" = "(RStudio|R Studio)",
                   "Python"  = "python",
                   "data science" = "data science",
                   "education" = "education",
                   "teaching" = "teaching"
                 ),
                 selected = "( R | R$)"
               ),
               
               # Other ----------------------------------------------
               textInput(
                 "keyword_text",
                 "Add additional keywords or phrases, separated by commas"
               ),
               
               br(),
               
               # Excluded fee events --------------------------------
               checkboxInput("exclude_fee",
                             "Exclude added fee events"),
               
               br(),
               hr(),
               br(),
               
               # Footnote -------------------------------------------
               HTML('For the official JSM 2019 website, including conference information, registration for short courses, and an online program with more customization options, visit <a href="https://ww2.amstat.org/meetings/jsm/2019/onlineprogram/index.cfm">here</a>.')
               
             ),
             
             # Output -----------------------------------------------
             mainPanel(DT::dataTableOutput(outputId = "talks"))
             
           ))
)

# Server ------------------------------------------------------------
server <- function(input, output) {
  
  # Sessions --------------------------------------------------------
  output$schedule <- DT::renderDataTable({
    
    # Require inputs ------------------------------------------------
    req(input$day)
    
    # Wrangle sponsor text ------------------------------------------
    sponsor_string <- glue_collapse(input$sponsor, sep = "|")
    if (length(sponsor_string) == 0)
      sponsor_string <- ".*"
    
    session_type <- input$type
    if (length(session_type) == 0)
      session_type <- types
    
    # Exclude fee events --------------------------------------------
    if (input$exclude_fee) {
      jsm_sessions <- jsm_sessions %>% filter(has_fee == FALSE)
    }
    
    # Add session title filter
    keywords <- input$session_keyword_text %>%
      str_split(",") %>%
      purrr::pluck(1) %>%
      str_trim() %>%
      discard( ~ .x == "")
    
    keyword_regex <- keywords
    
    if (length(keyword_regex) == 0) {
      keyword_regex = ""
    }
    
    matching_titles <- keyword_regex %>%
      tolower() %>%
      map(str_detect, string = tolower(jsm_sessions$session)) %>%
      reduce(`&`)
    
    # Filter and tabulate data --------------------------------------
    jsm_sessions %>%
      filter(
        day %in% input$day,
        type %in% session_type,
        beg_time_round >= input$time[1],
        end_time_round <= input$time[2],
        str_detect(sponsor, sponsor_string),
        matching_titles
      ) %>%
      mutate(
        date_time = glue("{day}, {date}<br/>{time}"),
        session = glue('<a href="{url}" target="_blank">{session}</a>')
      ) %>%
      select(date_time, session, location, type, sponsor) %>%
      DT::datatable(rownames = FALSE, escape = FALSE) %>%
      formatStyle(columns = "date_time",
                  fontSize = "80%",
                  width = "100px") %>%
      formatStyle(columns = "session", width = "450px") %>%
      formatStyle(columns = c("location", "type"), width = "100px") %>%
      formatStyle(columns = "sponsor",
                  fontSize = "80%",
                  width = "200px")
    
  })
  
  # Talks -----------------------------------------------------------
  output$talks <- DT::renderDataTable({
    # Exclude fee events
    if (input$exclude_fee) {
      jsm_talks <- jsm_talks %>% filter(has_fee == FALSE)
    }
    
    # Create pattern
    keywords <- input$keyword_text %>%
      str_split(",") %>%
      purrr::pluck(1) %>%
      str_trim() %>%
      discard( ~ .x == "")
    
    keyword_regex <- c(input$keyword_choice, keywords)
    
    if (length(keyword_regex) == 0) {
      keyword_regex = ""
    }
    
    matching_titles <- keyword_regex %>%
      tolower() %>%
      map(str_detect, string = tolower(jsm_talks$title)) %>%
      reduce(`&`)
    
    # Subset for pattern
    jsm_talks %>%
      filter(matching_titles) %>%
      mutate(title = glue('<a href="{url}" target="_blank">{title}</a>')) %>%
      select(title) %>%
      DT::datatable(
        rownames = FALSE,
        escape = FALSE,
        options = list(dom = "ltp")
      )
    
  })
}

# Create the app object ---------------------------------------------
shinyApp(ui, server)
