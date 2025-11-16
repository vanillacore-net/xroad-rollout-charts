#!/bin/bash
# Quick script to stop any running run_config.sh instances and their Docker containers

echo "=== Stopping run_config.sh ==="
echo ""

# Find and kill Hurl Docker containers
echo "1. Stopping Hurl Docker containers..."
HURL_CONTAINERS=$(docker ps --filter "ancestor=orangeopensource/hurl:1.8.0" --format "{{.ID}}" 2>/dev/null)
if [ -n "$HURL_CONTAINERS" ]; then
    echo "   Found containers: $HURL_CONTAINERS"
    echo "$HURL_CONTAINERS" | xargs docker kill 2>/dev/null && echo "   ✓ Containers stopped" || echo "   ⚠️  Failed to stop some containers"
else
    echo "   No Hurl containers running"
fi

# Kill the script process itself
echo ""
echo "2. Stopping run_config.sh processes..."
if pkill -f 'run_config.sh' 2>/dev/null; then
    echo "   ✓ Script processes stopped"
else
    echo "   No run_config.sh processes found"
fi

# Clean up any stopped containers
echo ""
echo "3. Cleaning up stopped containers..."
docker container prune -f --filter "ancestor=orangeopensource/hurl:1.8.0" >/dev/null 2>&1

echo ""
echo "✓ Cleanup complete!"

