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

# Criar scripts diretamente no Dockerfile
RUN echo '#!/bin/bash\n\
    until redis-cli -h redis -p 6379 ping | grep PONG; do\n\
    echo "Aguardando Redis responder PING..."\n\
    sleep 1\n\
    done\n\
    echo "Iniciando API Plumber..."\n\
    exec R -e "pr <- plumber::plumb(\\"api.R\\"); pr\\$run(host=\\"0.0.0.0\\", port=9999, swagger=FALSE)"' > /app/wait-for-redis.sh

RUN echo '#!/bin/bash\n\
    until redis-cli -h redis -p 6379 ping | grep PONG; do\n\
    echo "Aguardando Redis responder PING..."\n\
    sleep 1\n\
    done\n\
    echo "Redis conectado! Iniciando worker.R..."\n\
    exec R --no-restore --no-save -e "source(\\"worker.R\\")"' > /app/start-worker.sh

WORKDIR /app

RUN chmod +x /app/wait-for-redis.sh
RUN chmod +x /app/start-worker.sh
RUN R -e "library(plumber); library(httr2)"

CMD ["/app/wait-for-redis.sh"]
