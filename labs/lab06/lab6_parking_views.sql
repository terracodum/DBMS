-- ============================================================================
-- Лабораторная работа № 6 — Представления
-- Источник: lab6_parking_views.ipynb
-- Подключение: parking.
-- Запуск: psql -X -v ON_ERROR_STOP=1 -d parking -f lab6_parking_views.sql
-- Или откройте файл в Query Tool pgAdmin и выполните целиком.
-- Скрипт содержит явную транзакцию; после ошибки выполните ROLLBACK.
-- После ЛР3; повторный запуск поддерживается при неизменных определениях объектов.
-- ============================================================================

BEGIN;

-- Подготовка схемы
-- Схема изолирует объекты работы от таблиц public.

CREATE SCHEMA IF NOT EXISTS lab6;

-- 1. Учебные примеры

-- 1.1. Число договоров по клиентам (стр. 121–122)
-- Аналог number_of_orders: вместо заказов считаем договоры.
-- COUNT(c.contr_id) при LEFT JOIN возвращает ноль для клиента без договоров.
-- Имена столбцов задаются явно: OR REPLACE не позволяет переименовывать
-- существующий столбец добавлением другого псевдонима; для этого есть ALTER VIEW.

CREATE OR REPLACE VIEW lab6.v_client_contract_counts AS
SELECT cl.cl_id, cl.cl_name, COUNT(c.contr_id) AS contract_count
FROM public.clients cl
LEFT JOIN public.contracts c ON c.contr_client_id = cl.cl_id
GROUP BY cl.cl_id, cl.cl_name;

-- Выборка из представления
-- Сортировка задаётся во внешнем SELECT.

SELECT * FROM lab6.v_client_contract_counts ORDER BY cl_id;

-- 1.2. Суммарная стоимость договоров по категориям (стр. 122)
-- Аналог price_view. Здесь суммируются суммы договоров, а не цены тарифов
-- с разными периодами. WITH DATA сразу сохраняет результат. Повторный запуск
-- обновляет снимок отдельной командой REFRESH.

CREATE MATERIALIZED VIEW IF NOT EXISTS lab6.mv_category_amounts AS
SELECT cat.cat_id, cat.cat_name, COUNT(c.contr_id) AS contract_count,
       COALESCE(SUM(c.contr_amount), 0)::numeric(14,2) AS total_amount
FROM public.vehicle_categories cat
LEFT JOIN public.vehicles v ON v.veh_cat_id = cat.cat_id
LEFT JOIN public.contracts c ON c.contr_veh_id = v.veh_id
GROUP BY cat.cat_id, cat.cat_name
WITH DATA;

-- Обновление снимка
-- Материализованное представление обновляется явно.

REFRESH MATERIALIZED VIEW lab6.mv_category_amounts;

-- Выборка по категориям
-- LEFT JOIN оставляет категории без договоров.

SELECT cat.cat_name, mv.contract_count, mv.total_amount
FROM public.vehicle_categories cat
LEFT JOIN lab6.mv_category_amounts mv ON mv.cat_id = cat.cat_id
ORDER BY cat.cat_id;

-- 1.3. Клиенты со скидкой (стр. 123)
-- Аналог cust_view. WITH NO DATA создаёт ненаполненное представление.
-- До первого REFRESH чтение вызывает ошибку SQLSTATE 55000.
-- На повторном запуске IF NOT EXISTS сохраняет уже созданный объект.

CREATE MATERIALIZED VIEW IF NOT EXISTS lab6.mv_discount_clients AS
SELECT cl_id, cl_name, cl_type, cl_discount
FROM public.clients WHERE cl_discount > 0
WITH NO DATA;

-- Ненаполненное представление: ожидаемая ошибка изолирована подблоком.
DO $$
BEGIN
    IF NOT (SELECT ispopulated FROM pg_matviews
            WHERE schemaname = 'lab6' AND matviewname = 'mv_discount_clients') THEN
        BEGIN
            PERFORM * FROM lab6.mv_discount_clients;
            RAISE EXCEPTION 'Ожидалась ошибка 55000';
        EXCEPTION WHEN object_not_in_prerequisite_state THEN
            RAISE NOTICE '55000: сначала требуется REFRESH MATERIALIZED VIEW';
        END;
    ELSE
        RAISE NOTICE 'Повторный запуск: представление уже наполнено';
    END IF;
END;
$$;

-- Наполнение
-- Теперь представление можно читать.

REFRESH MATERIALIZED VIEW lab6.mv_discount_clients;

-- Клиенты со скидкой по возрастанию скидки
-- Код клиента разрешает равенства при сортировке.

SELECT * FROM lab6.mv_discount_clients ORDER BY cl_discount, cl_id;

-- 2. Индивидуальные представления

-- 2.1. Подробности договоров — обычное представление
-- Каждая строка — один договор: клиент, автомобиль, место и сумма.
-- Значение статуса берётся из учебных данных; текущая дата не используется.

CREATE OR REPLACE VIEW lab6.v_contract_details AS
SELECT c.contr_id, c.contr_number, c.contr_client_id AS cl_id,
       cl.cl_name, cl.cl_type, v.veh_plate, cat.cat_name,
       p.pl_sector, p.pl_number, c.contr_amount, c.contr_status
FROM public.contracts c
JOIN public.clients cl ON cl.cl_id = c.contr_client_id
JOIN public.vehicles v ON v.veh_id = c.contr_veh_id
JOIN public.vehicle_categories cat ON cat.cat_id = v.veh_cat_id
JOIN public.places p ON p.pl_id = c.contr_place_id;

-- 2.2. Расчёты по договорам — обычное представление
-- Платежи сначала группируются по договору, затем присоединяются.
-- Это сохраняет одну строку на договор и не умножает его сумму на число квитанций.
-- balance — сумма договора минус все платежи; отрицательное значение означает
-- переплату. Штрафы и возвраты в этой учебной схеме отдельно не учитываются.

CREATE OR REPLACE VIEW lab6.v_contract_balances AS
SELECT d.*, COALESCE(p.paid_amount, 0)::numeric(14,2) AS paid_amount,
       (d.contr_amount - COALESCE(p.paid_amount, 0))::numeric(14,2) AS balance
FROM lab6.v_contract_details d
LEFT JOIN (
    SELECT pay_contr_id, SUM(pay_sum) AS paid_amount
    FROM public.payments GROUP BY pay_contr_id
) p ON p.pay_contr_id = d.contr_id;

-- Проверка расчётов
-- Выводятся все договоры, включая полностью оплаченные.

SELECT contr_number, cl_name, contr_amount, paid_amount, balance FROM lab6.v_contract_balances ORDER BY contr_id;

-- 3. Три запроса индивидуального задания

-- 3.a. Выборка с вложенным запросом
-- Вывести договоры, сумма которых превышает среднюю сумму всех договоров.
-- Основной и вложенный запросы обращаются к представлению.

SELECT contr_number, cl_name, contr_amount
FROM lab6.v_contract_details
WHERE contr_amount > (SELECT AVG(contr_amount) FROM lab6.v_contract_details)
ORDER BY contr_id;

-- 3.b. Группировка и простая сортировка
-- Определить число клиентов со скидкой и среднюю скидку по типам клиентов.
-- Простая сортировка — по одному полю, типу клиента.

SELECT cl_type, COUNT(*) AS client_count,
       ROUND(AVG(cl_discount), 2) AS average_discount
FROM lab6.mv_discount_clients
GROUP BY cl_type
ORDER BY cl_type;

-- 3.c. Группировка и многоуровневая сортировка
-- По типу клиента и сектору определить число договоров и суммы начислений,
-- оплаты и остатка. Сначала сортировать остаток по убыванию, затем начисления
-- по убыванию, затем тип и сектор по возрастанию.

SELECT cl_type, pl_sector, COUNT(*) AS contract_count,
       SUM(contr_amount) AS total_amount, SUM(paid_amount) AS paid_amount,
       SUM(balance) AS balance
FROM lab6.v_contract_balances
GROUP BY cl_type, pl_sector
ORDER BY balance DESC, total_amount DESC, cl_type ASC, pl_sector ASC;

-- 4. Проверка обычного представления и снимка
-- В savepoint временно увеличим сумму одного договора на 100. Обычное
-- представление сразу покажет изменение, материализованное — после REFRESH.
-- ROLLBACK TO отменяет и изменение договора, и обновление снимка.

-- Изменение действует только внутри savepoint.
SAVEPOINT refresh_demo;

SELECT SUM(contr_amount) AS before_update
FROM lab6.v_contract_details;

UPDATE public.contracts
SET contr_amount = contr_amount + 100
WHERE contr_id = (SELECT MIN(contr_id) FROM public.contracts);

SELECT SUM(contr_amount) AS live_view_after_update
FROM lab6.v_contract_details;

SELECT SUM(total_amount) AS snapshot_before_refresh
FROM lab6.mv_category_amounts;

REFRESH MATERIALIZED VIEW lab6.mv_category_amounts;

SELECT SUM(total_amount) AS snapshot_after_refresh
FROM lab6.mv_category_amounts;

-- Откатываются и сумма договора, и обновление снимка.
ROLLBACK TO SAVEPOINT refresh_demo;
RELEASE SAVEPOINT refresh_demo;

SELECT (SELECT SUM(contr_amount) FROM lab6.v_contract_details) AS restored_amount,
       (SELECT SUM(total_amount) FROM lab6.mv_category_amounts) AS restored_snapshot;

-- Состав созданных объектов
-- Три обычных и два материализованных представления.

SELECT viewname AS object_name, 'VIEW' AS object_type
FROM pg_views WHERE schemaname = 'lab6'
UNION ALL
SELECT matviewname, 'MATERIALIZED VIEW'
FROM pg_matviews WHERE schemaname = 'lab6'
ORDER BY object_type, object_name;

COMMIT;
