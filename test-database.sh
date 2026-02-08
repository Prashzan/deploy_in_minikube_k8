#!/bin/bash

# Database Testing Script for Kubernetes
# Connect to PostgreSQL pod and run queries

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Kubernetes Database Test Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get PostgreSQL pod name
POD_NAME=$(kubectl get pods -n weather-app -l app=postgres -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo -e "${YELLOW}PostgreSQL pod not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found PostgreSQL pod: $POD_NAME${NC}"
echo ""

# Main menu
while true; do
    echo ""
    echo "What would you like to do?"
    echo "1. View table structure"
    echo "2. Count total weather searches"
    echo "3. View last 10 searches"
    echo "4. View searches for a specific city"
    echo "5. View statistics (most searched cities)"
    echo "6. View average temperature by city"
    echo "7. Connect to PostgreSQL shell (interactive)"
    echo "8. View all data"
    echo "9. Delete all data (reset database)"
    echo "10. Exit"
    echo ""
    read -p "Enter your choice (1-10): " choice

    case $choice in
        1)
            echo -e "${BLUE}Table structure:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "\d weather_searches"
            ;;
        2)
            echo -e "${BLUE}Total searches:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT COUNT(*) as total_searches FROM weather_searches;"
            ;;
        3)
            echo -e "${BLUE}Last 10 searches:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT city_name, country, temperature, humidity, searched_at FROM weather_searches ORDER BY searched_at DESC LIMIT 10;"
            ;;
        4)
            read -p "Enter city name: " city
            echo -e "${BLUE}Searches for $city:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT * FROM weather_searches WHERE city_name ILIKE '%$city%' ORDER BY searched_at DESC;"
            ;;
        5)
            echo -e "${BLUE}Most searched cities:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT city_name, COUNT(*) as search_count FROM weather_searches GROUP BY city_name ORDER BY search_count DESC LIMIT 10;"
            ;;
        6)
            echo -e "${BLUE}Average temperature by city:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT city_name, ROUND(AVG(temperature)::numeric, 2) as avg_temp, COUNT(*) as searches FROM weather_searches GROUP BY city_name ORDER BY searches DESC;"
            ;;
        7)
            echo -e "${BLUE}Connecting to PostgreSQL shell...${NC}"
            echo "Type 'exit' or '\q' to return to this menu"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb
            ;;
        8)
            echo -e "${BLUE}All data:${NC}"
            kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "SELECT * FROM weather_searches ORDER BY searched_at DESC;"
            ;;
        9)
            read -p "Are you sure you want to delete all data? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                echo -e "${YELLOW}Deleting all data...${NC}"
                kubectl exec -it $POD_NAME -n weather-app -- psql -U weatheruser -d weatherdb -c "DELETE FROM weather_searches;"
                echo -e "${GREEN}✓ All data deleted${NC}"
            else
                echo "Cancelled"
            fi
            ;;
        10)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Please enter 1-10.${NC}"
            ;;
    esac
done
