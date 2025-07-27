#!/bin/sh
until redis-cli -h redis -p 6379 ping | grep PONG; do
  echo "Aguardando Redis responder PING..."
  sleep 1
done
exec R -e "pr <- plumber::plumb('api.R'); pr\$run(host='0.0.0.0', port=9999)"