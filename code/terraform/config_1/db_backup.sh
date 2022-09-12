#!/bin/bash
if test -f "../../backup/db/backup.sql"; then
    mysql -h inventoriadb.cccqkewazeyi.eu-central-1.rds.amazonaws.com -u tom -pPa55w.rd inventoriadb < ../../backup/db/backup.sql
fi
