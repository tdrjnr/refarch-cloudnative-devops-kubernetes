#!/bin/bash
# URI parsing function
#
# The function creates global variables with the parsed results.
# It returns 0 if parsing was successful or non-zero otherwise.
#
# [schema://][user[:password]@]host[:port][/path][?[arg1=val1]...][#fragment]
#
# from http://vpalos.com/537/uri-parsing-using-bash-built-in-features/
#

# URI parsing function
#
# The function creates global variables with the parsed results.
# It returns 0 if parsing was successful or non-zero otherwise.
#
# [schema://][user[:password]@]host[:port][/path][?[arg1=val1]...][#fragment]
#
# from http://vpalos.com/537/uri-parsing-using-bash-built-in-features/

source ./helper.sh

# Checks for mysql "variable" set by Kubernetes secret
if [ -z ${mysql+x} ]; then 
    echo "Secret not in \"mysql\" variable. Aborting...";
    exit 1
fi

echo "Found mysql secret"
mysql_uri=$(echo $mysql | jq -r '.uri')

# Do the URL parsing
uri_parser $mysql_uri

# Extract MySQL url
mysql_user=${uri_user}
mysql_password=${uri_password}
mysql_host=${uri_host}
mysql_port=${uri_port}
# drop the leading '/' from the path
mysql_database=`echo ${uri_path} | sed -e 's/^\///'`


# Optional
if [[ -z "$mysql_host" ]]; then
	echo "Host not provided. Using localhost..."
	mysql_host='0.0.0.0'
fi

if [[ -z "$mysql_port" ]]; then
	echo "Port not provided. Using 3306..."
	mysql_port='3306'
fi

if [[ -z "$mysql_database" ]]; then
	echo "Database not provided. Attempting container environment variable..."
	mysql_database=$MYSQL_DATABASE
fi

# wget the URL of the sql file to execute
SQL_URL=$1
if [ -z "${SQL_URL}" ]; then
    echo "No SQL Script was provided"
    exit 0
fi

wget ${SQL_URL} -O load-data.sql
if [ $? -ne 0 ]; then
    echo "Failed to download ${SQL_URL}"
    exit 1
fi

echo "Executing MySQL script ${SQL_URL} on MySQL database ${mysql_host}:${mysql_port} ..."

# load data
while !(mysql -v -u${mysql_user} -p${mysql_password} --host ${mysql_host} --port ${mysql_port} <load-data.sql)
do
  printf "Waiting for MySQL to fully initialize\n\n"
  sleep 1
    echo "trying to load data again"
done

#rm load-data.sql testdata
printf "\n\nExecuted script at ${SQL_URL} on database %s\n\n" "${mysql_database}"
