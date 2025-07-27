#options(repos = c(CRAN = "https://cloud.r-project.org"))
#install.packages(c("plumber", "uuid", "jsonlite", "redux", "RPostgres", "DBI"))

library(plumber)
library(uuid)
library(jsonlite)
library(redux)

redis <- redux::hiredis(host = "redis", port = 6379)
payments <- function(req, res) {
    body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) NULL)
    if (is.null(body) || is.null(body$amount) || is.null(body$uuid)) {
        res$status <- 400
        return()
    }
    if (!is.numeric(body$amount) || body$amount <= 0) {
        res$status <- 400
        return()
    }
    amount_cents <- as.integer(round(body$amount * 100))
    redis$LPUSH("payments", jsonlite::toJSON(list(
        uuid = body$uuid,
        amount = amount_cents
    ), auto_unbox = TRUE))
    res$status <- 200
    return(list(status = "ok"))
}

payments_summary <- function(from, to){
    return(list(summary = "not implemented"))
}

#* @plumber
function(pr) {
  pr %>%
    pr_post("/payments", payments) %>%
    pr_get("/payments-summary", payments_summary)
}
