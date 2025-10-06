# ============================================
# PostgreSQL Initialization Script
# Creates multiple databases for different services
# ============================================

set -e
set -u

function create_database() {
    local database=$1
    echo "Creating database: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

# Check if multiple databases are specified
if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Creating multiple databases: $POSTGRES_MULTIPLE_DATABASES"
    
    # Split comma-separated database names
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_database $db
    done
    
    echo "Multiple databases created successfully"
else
    echo "POSTGRES_MULTIPLE_DATABASES not specified, skipping"
fi
