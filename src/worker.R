
tryCatch({
  library(httr2)
  library(jsonlite)
  library(redux)
}, error = function(e) {
  stop("Não foi possível carregar as bibliotecas necessárias")
})

connect_redis <- function(max_attempts = 10) {
  for (attempt in 1:max_attempts) {
    tryCatch({
      redis <- redux::hiredis(host = "redis", port = 6379)
      ping_result <- redis$PING()
      return(redis)
    }, error = function(e) {
      if (attempt >= max_attempts) {
        stop("Não foi possível conectar ao Redis após", max_attempts, "tentativas")
      }
    })
  }
}

redis <- connect_redis()

health_check_config <- list(
  default = list(url = "http://payment-processor-default:8080", healthy = TRUE, last_check = Sys.time() - 10, cache_duration = 2),
  fallback = list(url = "http://payment-processor-fallback:8080", healthy = TRUE, last_check = Sys.time() - 10, cache_duration = 2)
)

config <- list(
  health_check_interval = 1,
  max_retries = 1,
  payment_timeout = 1.5,
  health_timeout = 1,
  batch_size = 15,
  fallback_threshold = 2,
  max_concurrent = 3,
  sleep_idle = 0.0001,
  sleep_active = 0.00001
)

check_health_processor <- function(processor) {
  
  time_since_check <- as.numeric(difftime(Sys.time(), health_check_config[[processor]]$last_check, units = "secs"))
  
  if (time_since_check < health_check_config[[processor]]$cache_duration) {
    
    return(health_check_config[[processor]]$healthy)
  }
  
  
  base_url <- health_check_config[[processor]]$url
  health_url <- paste0(base_url, "/payments/service-health")
  
  result <- tryCatch({
    response <- request(health_url) |>
      req_timeout(config$health_timeout) |>
      req_perform()
    
    health_check_config[[processor]]$healthy <<- TRUE
    health_check_config[[processor]]$last_check <<- Sys.time()
    
    return(TRUE)
    
  }, error = function(err) {
    
    if (grepl("429", as.character(err))) {
      return(health_check_config[[processor]]$healthy)
    }
    
    health_check_config[[processor]]$healthy <<- FALSE
    health_check_config[[processor]]$last_check <<- Sys.time()
    
    return(FALSE)
  })
  
  return(result)
}

req_processor <- function(processor){
  base_url <- health_check_config[[processor]]$url
  health_url <- paste0(base_url, "/payments")
  
  json_data <- redis$RPOP("payments_queue")
  if (is.null(json_data)) {
    return(NULL)
  }

  payment_data <- tryCatch({
    data <- jsonlite::fromJSON(json_data)

    if (is.null(data$correlationId) || is.null(data$amount)) {
      stop("Missing required fields")
    }
    data

  }, error = function(e) {
    NULL
  })

  if (is.null(payment_data)) {
    return(list(success = FALSE, reason = "invalid_data"))
  }
  
  if (is.null(payment_data$requestedAt)) {
    payment_data$requestedAt <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S.000Z", tz = "UTC")
  } else {
    if (!grepl("T.*Z$", payment_data$requestedAt)) {
      payment_data$requestedAt <- paste0(gsub(" ", "T", payment_data$requestedAt), ".000Z")
    }
  }
  
  result <- tryCatch({
    
    res <- request(health_url) |>
      req_method("POST") |>
      req_body_json(payment_data) |>
      req_timeout(config$payment_timeout) |>
      req_perform()

    status_code <- resp_status(res)
    res_body <- tryCatch(resp_body_string(res), error=function(e) "<sem corpo>")

    log_entry <- list(
      correlationId = payment_data$correlationId,
      amount = as.numeric(payment_data$amount),
      source = processor,
      timestamp = as.numeric(Sys.time()),
      status = "success"
    )

    redis$ZADD("payments:logs", as.numeric(Sys.time()), jsonlite::toJSON(log_entry, auto_unbox = TRUE))

    return(list(
      success = TRUE,
      processor = processor,
      correlationId = payment_data$correlationId,
      status_code = status_code,
      response = res,
      response_body = res_body
    ))

  }, error = function(err) {
    res_body <- NA
    if (exists("res")) {
      res_body <- tryCatch(resp_body_string(res), error=function(e) "<sem corpo>")
    }

    if (grepl("timeout|connection", tolower(as.character(err)))) {
      redis$LPUSH("payments_queue", json_data)
    }

    return(list(
      success = FALSE,
      reason = "request_failed",
      error = as.character(err),
      correlationId = payment_data$correlationId,
      response_body = res_body
    ))
  })

  return(result)
}

process_batch <- function() {
  tryCatch({
    queue_length <- tryCatch({
      redis$LLEN("payments_queue")
    }, error = function(e) {
      return(0)
    })
    
    if (queue_length == 0) {
      return()
    }
    
    batch_size <- min(queue_length, config$batch_size)
    processed_count <- 0
  
    for (i in 1:batch_size) {
      processed <- FALSE
      
      if (check_health_processor("default")) {
        result <- req_processor("default")

        if (!is.null(result) && is.list(result) && !is.null(result$success) && isTRUE(result$success)) {
          processed <- TRUE
          processed_count <- processed_count + 1
        }
      }
      
      if (!processed) {
        if (check_health_processor("fallback")) {
          result <- req_processor("fallback")
          
          if (!is.null(result) && is.list(result) && !is.null(result$success) && isTRUE(result$success)) {
            processed <- TRUE
            processed_count <- processed_count + 1
          } else {
            break
          }
        } else {
          break
        }
      }
    }
    
  }, error = function(e) {
  })
}

while (TRUE) {
  tryCatch({
    process_batch()
    
  }, error = function(e) {
  })
}