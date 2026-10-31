-- ============================================================================
-- Лабораторная работа № 2 — создание базы sales
-- Источник: lab2_sales_db.ipynb
-- Подключение: postgres (служебная база).
-- Запуск: psql -X -v ON_ERROR_STOP=1 -d postgres -f lab2_sales_db.sql
-- В pgAdmin выделите CREATE DATABASE и выполните отдельно; затем выполните SELECT.
-- CREATE DATABASE выполняется отдельно, вне BEGIN/COMMIT; база создаётся один раз.
-- Если база уже существует, пропустите CREATE DATABASE. Существующая БД не удаляется.
-- ============================================================================

-- 1. Создание базы

CREATE DATABASE sales
    ENCODING 'UTF8'
    TEMPLATE template0;

-- 2. Проверка параметров

SELECT datname, pg_encoding_to_char(encoding) AS encoding, datcollate, datctype FROM pg_database WHERE datname = 'sales';
