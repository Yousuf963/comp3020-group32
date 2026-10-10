
# COMP3020 Group 32: Who Shapes Cybersecurity Conversation on Bluesky?

Group 32: Yousuf Hossain Munna (20397249), Seemrah Panwala (22175168), Rishikanth Goud Nimmala (22170637)

## Files
- `scripts/Collect.R`: collects posts and the follow network from Bluesky (run once; needs a Bluesky app password)
- `scripts/Clean.R`: cleans the raw data and saves the files in `data/`
- `data/`: frozen data snapshot (raw posts, cleaned posts, follow edges, cleaning log)
- `Report_Group32.Rmd`: main report; knits sections `01_data.Rmd` to `06_findings.Rmd`
- `Report_Group32.pdf`: rendered report
- `Group32_Poster.pdf`: poster

## How to reproduce
1. Open `Comp3020-Group32.Rproj` in RStudio.
2. Install packages: `install.packages(c("tidyverse", "tidytext", "igraph", "knitr", "rmarkdown"))`
3. Knit `Report_Group32.Rmd` to PDF. It uses only the saved files in `data/`, so it does not call the API.

To re-collect data, run `scripts/Collect.R` (requires `atrrr` and your own app password), then `scripts/Clean.R`. A new collection will give different posts.
