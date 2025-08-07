library(plumber)
library(uuid)
library(jsonlite)
library(redux)
library(lubridate)

`%||%` <- function(x, y) if (is.null(x)) y else x

redis <- redux::hiredis(host = "redis", port = 6379)

#* @post /payments
payments <- function(req, res) {
    body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) NULL)

    amount_reais <- as.numeric(body$amount)
    
    payload <- jsonlite::toJSON(list(
        correlationId = body$correlationId,
        amount = amount_reais,
        requestedAt = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
    ), auto_unbox = TRUE)
    
    redis$LPUSH("payments_queue", payload)
    res$status <- 202
    return(list(status = "accepted"))
}

#* @get /payments-summary
#* @serializer unboxedJSON
payments_summary <- function(from = NULL, to = NULL) {
    tryCatch({
        
        total_req_default <- 0L
        total_amt_default <- 0L
        total_req_fallback <- 0L
        total_amt_fallback <- 0L
        
        
        queue_entries <- redis$LRANGE("payments_queue", 0, -1)
        all_keys <- tryCatch({
            redis$KEYS("*")
        }, error = function(e) {
            return(c())
        })

        if (is.null(from) && is.null(to)) {
            entries <- redis$ZRANGE("payments:logs", 0, -1)
        } else {
            
            if (is.null(from)) from <- "1970-01-01T00:00:00.000Z"
            if (is.null(to)) to <- "2099-12-31T23:59:59.999Z"    
            
            from_time <- tryCatch({
                lubridate::ymd_hms(from, tz = "UTC")
            }, error = function(e) {
                lubridate::ymd_hms("1970-01-01T00:00:00.000Z", tz = "UTC")
            })
            
            to_time <- tryCatch({
                lubridate::ymd_hms(to, tz = "UTC")
            }, error = function(e) {
                lubridate::ymd_hms("2099-12-31T23:59:59.999Z", tz = "UTC")
            })
    
            from_epoch <- as.numeric(from_time) * 1000
            to_epoch <- as.numeric(to_time) * 1000
            
            entries <- redis$ZRANGEBYSCORE("payments:logs", from_epoch, to_epoch)
            
            if (length(entries) == 0 && "payments:log" %in% all_keys) {
                entries <- redis$ZRANGEBYSCORE("payments:log", from_epoch, to_epoch)
            }
        }
        
        if (length(entries) > 0) {
            if (length(entries) > 0) {
                for (i in 1:min(3, length(entries))) {
                    entry_parsed <- tryCatch(jsonlite::fromJSON(entries[i]), error = function(e) {
                        return(NULL)
                    })
                    if (!is.null(entry_parsed)) {
                    }
                }
            }
            
            all_logs <- lapply(entries, function(entry) {
                tryCatch(jsonlite::fromJSON(entry), error = function(e) NULL)
            })
            
            valid_logs <- all_logs[!sapply(all_logs, is.null)]

            if (length(valid_logs) > 0) {
                print(valid_logs[[1]])
                
                sources <- sapply(valid_logs, function(log) log$source %||% "")
                amounts <- sapply(valid_logs, function(log) {
                    amt <- log$amount %||% 0
                    as.numeric(amt)  # Manter como reais
                })
                
                default_mask <- sources == "default"
                fallback_mask <- sources == "fallback"
                
                total_req_default <- sum(default_mask)
                total_amt_default <- sum(amounts[default_mask])
                total_req_fallback <- sum(fallback_mask) 
                total_amt_fallback <- sum(amounts[fallback_mask])
                
            }
        }
        
        result <- list(
            default = list(
                totalRequests = jsonlite::unbox(total_req_default),
                totalAmount = jsonlite::unbox(total_amt_default)
            ),
            fallback = list(
                totalRequests = jsonlite::unbox(total_req_fallback),
                totalAmount = jsonlite::unbox(total_amt_fallback)
            )
        )
        
        return(result)
    }, error = function(e) {
        return(list(
            default = list(
                totalRequests = jsonlite::unbox(0L), 
                totalAmount = jsonlite::unbox(0L)
            ),
            fallback = list(
                totalRequests = jsonlite::unbox(0L), 
                totalAmount = jsonlite::unbox(0L)
            )
        ))
    })
}
