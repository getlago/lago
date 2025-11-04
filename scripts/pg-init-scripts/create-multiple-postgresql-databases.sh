#!/bin/bash

set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "Creating user and database '$database'"

	local db_exists=$(psql -U $POSTGRES_USER -tAc "SELECT 1 FROM pg_database WHERE datname='${database}'")

	if [ "${db_exists}" != "1" ]; then
		# Create the database
		createdb -U $POSTGRES_USER ${database}
		echo "Database ${database} created."
	else
		echo "Database ${database} already exists."
	fi
	local granted=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "GRANT ALL PRIVILEGES ON DATABASE \"$database\" TO \"$POSTGRES_USER\";" 2>&1)
	if [ "${granted}" == "GRANT" ]; then
		echo "Granted privileges on database ${database} to user ${POSTGRES_USER}."
	else
		echo "Failed to grant privileges on database ${database} to user ${POSTGRES_USER}: ${granted}"
	fi
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "Multiple databases created"
fi
