param()

$ErrorActionPreference = "Stop"

docker exec -e PGPASSWORD=qqtang_test_pass qqtang_account_pg_test psql -U qqtang_test -d qqtang_account_test -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;"
