#!/bin/bash

# Database utilities

create_database_and_user() {
    local db_name=$1
    local db_user=$2
    local db_password=$3
    
    sudo -u postgres psql << EOF
CREATE DATABASE $db_name;
CREATE USER $db_user WITH ENCRYPTED PASSWORD '$db_password';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\c $db_name
GRANT ALL ON SCHEMA public TO $db_user;
EOF
}

backup_database() {
    local db_name=$1
    local backup_file=$2
    
    sudo -u postgres pg_dump "$db_name" | gzip > "$backup_file"
}

restore_database() {
    local db_name=$1
    local backup_file=$2
    
    gunzip -c "$backup_file" | sudo -u postgres psql "$db_name"
}