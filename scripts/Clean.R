# scripts/clean.R
# Turns data/bluesky_raw.RData into the shared data/posts_clean.rds
# and records how many posts each step removed (for the report).

library(tidyverse)

load("data/bluesky_raw.RData")

step0 <- posts_raw
step1 <- step0 %>% distinct(uri, .keep_all = TRUE)        # same post found by both searches
step2 <- step1 %>% filter(map_lgl(langs, ~ "en" %in% unlist(.x)))   # English only

# Remove automated accounts. In the test pull, one vulnerability-alert bot
# (euvd-bot) wrote ~19% of posts and would dominate word counts and clusters.
# Step 1: flag every handle containing "bot".
bots <- posts_raw %>% distinct(author_handle) %>%
  filter(str_detect(author_handle, "bot")) %>% pull(author_handle)

# Manually reviewed all 13 handles containing "bot" on Bluesky (6 Oct 2026).
# These 4 are real people/organisations, not automated accounts, so they are kept.
false_positives <- c("ebottcher.bsky.social", "repeatablerobot.bsky.social",
                     "adybot.bsky.social", "progressiverobot.bsky.social")
bots <- setdiff(bots, false_positives)
bots                                                        # 9 confirmed bots: list in the report
step2b <- step2 %>% filter(!author_handle %in% bots)

step3 <- step2b %>%
  mutate(
    text      = str_squish(text),
    has_link  = map_int(links, NROW) > 0,
    is_reply  = !is.na(in_reply_to),
    n_words   = str_count(text, "\\S+"),
    n_mentions = map_int(mentions, NROW)    # mentions are stored as DIDs (account IDs)
  ) %>%
  filter(n_words >= 5)                                      # drop near-empty posts

posts <- step3 %>%
  transmute(id = uri, created_at = indexed_at, author = author_handle, text, query,
            has_link, is_reply, n_words,
            like_count, repost_count, reply_count, quote_count, n_mentions)

saveRDS(posts, "data/posts_clean.rds")
saveRDS(el_follow, "data/follow_edges.rds")

# ---- Cleaning summary for 01_data.Rmd ----
cleaning_log <- tibble(
  step  = c("Collected", "After removing duplicates",
            "After English-only filter", "After removing bot accounts",
            "After removing posts < 5 words"),
  posts = c(nrow(step0), nrow(step1), nrow(step2), nrow(step2b), nrow(step3))
) %>%
  mutate(removed = lag(posts) - posts)

print(cleaning_log)
saveRDS(cleaning_log, "data/cleaning_log.rds")

cat("Unique authors:", n_distinct(posts$author), "\n")
cat("Posts with >= 1 mention:", sum(posts$n_mentions > 0), "\n")
summary(posts$like_count)