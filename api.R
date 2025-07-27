options(repos = c(CRAN = "https://cloud.r-project.org"))
#install.packages(c("plumber", "uuid", "jsonlite", "redux"))

library(plumber)
library(uuid)
library(jsonlite)
library(redux)

redis <- redux::hiredis()

#* @POST /payments
#* @Serializer json
function(req, res) {
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
}

#* @GET /payments-summary
#* @Serializer json
function(from, to){
  library(DBI)
  library(RPostgres)

  con <- dbConnect(
    Postgres(),
    dbname = "meubanco",
    host = "localhost",
    port = 5432,
    user = "usuario",
    password = "senha"
  )
}




pr("api.R") %>%
    pr_run(port = 9999)
