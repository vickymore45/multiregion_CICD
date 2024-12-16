#!/bin/bash

cd src/

MIG=$(sequelize db:migrate:status --env environment | grep "down" | wc -l)

if [ "$MIG" -gt 0 ]; then
    echo "Pending migrations found. Executing migrations..."
    sequelize db:migrate --env environment
else
    echo "No pending migrations."
fi

cd .. && node server.js &

tail -f /dev/null
