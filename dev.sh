#!/bin/bash

set -e

CONTAINER_NAME="pg_unique_slug_dev"
DB_NAME="testdb"
DB_USER="postgres"

case "$1" in
  start)
    echo "Starting PostgreSQL container..."
    docker-compose up -d
    echo "Waiting for PostgreSQL to be ready..."
    sleep 3
    echo "PostgreSQL is ready!"
    ;;

  stop)
    echo "Stopping PostgreSQL container..."
    docker-compose down
    ;;

  restart)
    echo "Restarting PostgreSQL container..."
    docker-compose restart
    ;;

  build)
    echo "Building extension inside container..."
    docker exec -u root -it $CONTAINER_NAME bash -c "cd /extension && make clean && make && make install"
    echo "Extension built successfully!"
    ;;

  install)
    echo "Installing extension in database..."
    docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "DROP EXTENSION IF EXISTS pg_unique_slug CASCADE;"
    docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION pg_unique_slug;"
    echo "Extension installed successfully!"
    ;;

  rebuild)
    echo "Rebuilding and reinstalling extension..."
    $0 build
    $0 install
    ;;

  psql)
    echo "Connecting to PostgreSQL..."
    docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME
    ;;

  logs)
    echo "Showing PostgreSQL logs..."
    docker-compose logs -f
    ;;

  test)
    echo "Running regression tests..."
    docker exec -u root -it $CONTAINER_NAME bash -c "cd /extension && make installcheck PGUSER=postgres"
    echo ""
    echo "Check test/regression.diffs for any failures (empty = all passed)"
    ;;

  quicktest)
    echo "Running quick manual test..."
    docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOF'
-- Test different precision levels
SELECT 'Length 10 (seconds):' as test, gen_unique_slug(10) as slug;
SELECT 'Length 13 (millis):' as test, gen_unique_slug(13) as slug;
SELECT 'Length 16 (micros):' as test, gen_unique_slug(16) as slug;
SELECT 'Length 19 (nanos):' as test, gen_unique_slug(19) as slug;
SELECT 'Default (16):' as test, gen_unique_slug() as slug;

-- Generate multiple slugs
SELECT 'Multiple slugs:' as test;
SELECT gen_unique_slug() FROM generate_series(1, 5);

SELECT 'Quick test completed!' as result;
EOF
    ;;

  shell)
    echo "Opening shell in container..."
    docker exec -it $CONTAINER_NAME bash
    ;;

  clean)
    echo "Cleaning build artifacts..."
    rm -f *.o *.so *.bc
    echo "Clean complete!"
    ;;

  *)
    echo "pg_unique_slug Development Helper"
    echo ""
    echo "Usage: ./dev.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start      - Start PostgreSQL container"
    echo "  stop       - Stop PostgreSQL container"
    echo "  restart    - Restart PostgreSQL container"
    echo "  build      - Build extension inside container"
    echo "  install    - Install extension in database"
    echo "  rebuild    - Rebuild and reinstall extension"
    echo "  psql       - Connect to PostgreSQL"
    echo "  logs       - Show PostgreSQL logs"
    echo "  test       - Run regression tests (pg_regress)"
    echo "  quicktest  - Run quick manual test"
    echo "  shell      - Open bash shell in container"
    echo "  clean      - Clean build artifacts"
    echo ""
    exit 1
    ;;
esac
