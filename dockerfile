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

RUN R -e "install.packages('plumber', repos='https://cloud.r-project.org', quiet = FALSE)"
RUN R -e "install.packages(c('uuid', 'jsonlite', 'redux'), repos='https://cloud.r-project.org', quiet = FALSE)"

COPY api.R /app/api.R
COPY wait-for-redis.sh /app/wait-for-redis.sh

WORKDIR /app

RUN chmod +x /app/wait-for-redis.sh
RUN R -e "library(plumber)"

CMD ["/app/wait-for-redis.sh"]