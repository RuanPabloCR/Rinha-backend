#!/bin/sh
until redis-cli -h redis -p 6379 ping | grep PONG; do
  echo "Aguardando Redis responder PING..."
  sleep 1
done

echo "Redis conectado! Iniciando worker.R..."
exec R --no-restore --no-save -e "source('worker.R')"
