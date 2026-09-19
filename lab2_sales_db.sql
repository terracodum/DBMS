-- ============================
-- Лабораторная работа №2
-- Создание новой базы данных в среде PostgreSQL
-- ============================

-- Database: sales

-- DROP DATABASE IF EXISTS sales;

CREATE DATABASE sales
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Russian_Russia.1251'
    LC_CTYPE = 'Russian_Russia.1251'
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

COMMENT ON DATABASE sales
    IS 'База данных для службы оформления заказов на товары';
