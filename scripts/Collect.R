# scripts/collect.R
# Bluesky data collection for COMP3020 Group 32
#The report only loads the saved files and never calls the API.

library(atrrr)
library(tidyverse)
tinytex::install_tinytex()

dir.create("data", showWarnings = FALSE)


# ==== 2. TEST SEARCH ====
test <- search_post("cybersecurity", sort = "latest", limit = 100)

dim(test)                                   # want about 100 rows
names(test)                                 # expect text, like_count, mentions, langs...
head(test[, c("author_handle", "text", "like_count")], 5)
test$mentions[1:5]                          # what do mentions look like?
mean(map_int(test$mentions, NROW) > 0)      # share of posts with a mention


# ==== 3. FULL PULL: topic posts ====
queries <- c("cybersecurity", "infosec")

posts_raw <- map(queries, function(q) {
  search_post(q, sort = "latest", limit = 3000) %>%
    mutate(query = q)                       # remember which search found the post
}) %>%
  bind_rows()

collected_at <- Sys.time()

dim(posts_raw)
posts_raw %>% count(query)
range(posts_raw$indexed_at)                 # time window the posts cover


# Seed candidates: authors who posted about the topic at least 3 times,
# so the seed is an active voice in this discussion, not a one-off poster.
# Automated "bot" accounts are excluded so the seed is a real voice.

active_authors <- posts_raw %>%
  filter(!str_detect(author_handle, "bot")) %>%
  count(author_handle, sort = TRUE) %>%
  filter(n >= 3) %>%
  pull(author_handle)

author_info <- get_user_info(active_authors)

# Seed = the most-followed active author, but only
# among authors who follow at least 30 accounts, so the network has
# enough branches to be large and connected.
seed_candidates <- author_info %>% filter(follows_count >= 30)
seed_user_handle <- seed_candidates$actor_handle[which.max(seed_candidates$followers_count)]
seed_user_handle

# Direct friends (accounts the seed follows)
friends_handles <- get_follows(seed_user_handle, limit = 30)$actor_handle
length(friends_handles)

# Friends of friends
# A single server error (e.g. HTTP 502) should not stop the whole loop,
# so each request is wrapped: a failure is printed and returns no friends.
safe_follows <- function(h) {
  tryCatch(get_follows(h, limit = 50),
           error = function(e) {
             message("Failed for ", h, ": ", conditionMessage(e))
             NULL
           })
}

more_friends <- lapply(friends_handles, safe_follows)
more_friends_handles <- lapply(more_friends, function(x)
  if (is.null(x)) character(0) else x$actor_handle)

sapply(more_friends_handles, length)        # friends retrieved per direct friend
failed_friends <- friends_handles[sapply(more_friends_handles, length) == 0]
failed_friends                              # failed/empty retrievals: report in 2.5

# Directed edge list: one row = "from follows to"
el_seed <- cbind(from = rep(seed_user_handle, length(friends_handles)),
                 to   = friends_handles)

el_friends <- lapply(seq_along(friends_handles), function(i) {
  cbind(from = rep(friends_handles[i], length(more_friends_handles[[i]])),
        to   = more_friends_handles[[i]])
})

el_follow <- unique(rbind(el_seed, do.call(rbind, el_friends)))
el_follow <- el_follow[el_follow[, "from"] != el_follow[, "to"], , drop = FALSE]
dim(el_follow)


# ==== 5. SAVE THE FROZEN SNAPSHOT ====
save(posts_raw, author_info, seed_user_handle, friends_handles,
     more_friends_handles, failed_friends, el_follow, collected_at,
     file = "data/bluesky_raw.RData")

# Numbers for the 2.1 write-up
cat("Collected at:", format(collected_at), "\n")
cat("Posts collected:", nrow(posts_raw), "\n")
cat("Posts dated from", format(min(posts_raw$indexed_at)), "to",
    format(max(posts_raw$indexed_at)), "\n")
cat("Seed user:", seed_user_handle, "| follow edges:", nrow(el_follow), "\n")