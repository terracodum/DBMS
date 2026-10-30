#!/usr/bin/env bash
# =====================================================================
# РГР. Вариант 11 - "Автостоянка"
# Прогон всех SQL-скриптов на macOS / Linux (аналог run_all.ps1)
#
# Запуск:
#     cd archive/sql/parking
#     ./run_all.sh
# Параметры подключения - через переменные окружения:
#     PGHOST (127.0.0.1), PGPORT (5432), PGUSER (текущий пользователь)
#     PGPASSWORD, если нужен пароль
# База parking пересоздаётся с нуля.
# =====================================================================
set -u
cd "$(dirname "$0")"

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGCLIENTENCODING=UTF8

if ! command -v psql >/dev/null; then
    echo "psql не найден. Установите PostgreSQL: brew install postgresql@16" >&2
    exit 1
fi

run() {  # run <база> <файл> [без остановки на ошибках]
    echo
    echo ">>> $2  (база: $1)"
    if [ "${3:-}" = "allow-errors" ]; then
        psql -d "$1" -f "$2" -a -e
    else
        psql -d "$1" -f "$2" -a -e -v ON_ERROR_STOP=1 || { echo "ОШИБКА в $2" >&2; exit 1; }
    fi
}

# lab2_parking_db.sql рассчитан на Windows-локаль Russian_Russia.1251,
# поэтому на macOS/Linux база создаётся без неё
psql -d postgres -v ON_ERROR_STOP=1 \
     -c "DROP DATABASE IF EXISTS parking" \
     -c "CREATE DATABASE parking ENCODING 'UTF8' TEMPLATE template0" || exit 1

run parking lab3_parking_tables.sql
run parking lab3_parking_data.sql
run parking lab4_parking_array_json.sql
run parking lab4_textbook_example.sql
run parking lab5_parking_queries.sql

# integrity_tests.sql содержит заведомо ошибочные инструкции
run parking test/integrity_tests.sql allow-errors
run parking test/structure_report.sql

echo
echo "Все скрипты выполнены."
