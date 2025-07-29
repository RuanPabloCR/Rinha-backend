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
    if (is.null(body) || is.null(body$amount) || is.null(body$correlationId)) {
        res$status <- 400
        return()
    }
    if (!is.numeric(body$amount) || body$amount <= 0) {
        res$status <- 400
        return()
    }
    amount_cents <- as.integer(round(body$amount * 100))
    redis$LPUSH("payments_queue", jsonlite::toJSON(list(
        correlationId = body$correlationId,
        amount = amount_cents,
        requestedAt = Sys.time()
    ), auto_unbox = TRUE))
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
        
        
        if (is.null(from) && is.null(to)) {
            
            entries <- redis$ZRANGE("payments:logs", 0, -1)
        } else {
            
            if (is.null(from)) from <- "1970-01-01T00:00:00.000Z"
            if (is.null(to)) to <- "2099-12-31T23:59:59.999Z"    
            
            
            from_time <- tryCatch({
                as.POSIXct(from, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
            }, error = function(e) {
                as.POSIXct("1970-01-01T00:00:00.000Z", format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
            })
            
            to_time <- tryCatch({
                as.POSIXct(to, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
            }, error = function(e) {
                as.POSIXct("2099-12-31T23:59:59.999Z", format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
            })
            
            from_epoch <- as.numeric(from_time)
            to_epoch <- as.numeric(to_time)
            
            entries <- redis$ZRANGEBYSCORE("payments:logs", from_epoch, to_epoch)
        }
        
        if (length(entries) > 0) {
            cat("📊 DEBUG: Processando", length(entries), "entradas...\n")
            
            all_logs <- lapply(entries, function(entry) {
                tryCatch(jsonlite::fromJSON(entry), error = function(e) NULL)
            })
            
            
            valid_logs <- all_logs[!sapply(all_logs, is.null)]
            
            if (length(valid_logs) > 0) {
                sources <- sapply(valid_logs, function(log) log$source %||% "")
                amounts <- sapply(valid_logs, function(log) as.integer(log$amount %||% 0))
                
              
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
                totalAmount = jsonlite::unbox(total_amt_default / 100.0)
            ),
            fallback = list(
                totalRequests = jsonlite::unbox(total_req_fallback),
                totalAmount = jsonlite::unbox(total_amt_fallback / 100.0)
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
