FROM r-base:4.4.0

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libpq-dev \
    libv8-dev \
    libsodium-dev \
    libhiredis-dev \
    redis-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber', 'httr2', 'jsonlite', 'redux', 'uuid', 'lubridate'), repos='https://cloud.r-project.org', quiet = FALSE)"

COPY src/api.R /app/api.R
COPY src/worker.R /app/worker.R
COPY wait-for-redis.sh /app/wait-for-redis.sh
COPY start-worker.sh /app/start-worker.sh

WORKDIR /app

RUN chmod +x /app/wait-for-redis.sh
RUN chmod +x /app/start-worker.sh
RUN R -e "library(plumber); library(httr2)"

CMD ["/app/wait-for-redis.sh"]
