-- # Connect to postgres
-- POSTGRES_POD=$(kubectl get pods -n weather-app -l app=postgres -o jsonpath='{.items[0].metadata.name}')

-- kubectl exec -it $POSTGRES_POD -n weather-app -- psql -U weatheruser -d weatherdb

-- # Run SQL:
-- ALTER TABLE weather_searches ADD COLUMN IF NOT EXISTS cached BOOLEAN DEFAULT FALSE;
-- ALTER TABLE weather_searches ADD COLUMN IF NOT EXISTS response_time_ms INTEGER;

-- # Exit
-- \q

-- # Restart weather service
-- kubectl rollout restart deployment/weather-service -n weather-app