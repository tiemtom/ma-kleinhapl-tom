#!/bin/bash
if test -f "../../backup/db/backup.sql"; then
    mysql -h inventoriadb.mariadb.database.azure.com -u tom -pPa55w.rd inventoriadb < ../../backup/db/backup.sql
fi
