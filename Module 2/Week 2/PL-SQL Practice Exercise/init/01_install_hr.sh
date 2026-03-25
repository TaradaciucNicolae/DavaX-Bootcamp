#!/bin/bash
(
  set -Eeuo pipefail

  WORKDIR=/tmp/hr-install
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"

  cp /opt/hr-schema/*.sql "$WORKDIR"/
  cd "$WORKDIR"

  sqlplus -s system/"${ORACLE_PASSWORD}"@//localhost:1521/FREEPDB1 <<SQL
@hr_install.sql
${HR_PASSWORD}
USERS
YES
exit
SQL
)