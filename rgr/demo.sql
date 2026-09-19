-- =====================================================================
-- РГР, вариант 11 — «Автостоянка». ПОКАЗ ВЫПОЛНЕННОЙ РАБОТЫ
-- Выполнять на базе parking. Каждый запрос — по одному (выделить + F5)
-- =====================================================================
 -- #####################################################################
-- ПУНКТ ЗАДАНИЯ 1: СОЗДАТЬ БАЗУ ДАННЫХ
-- #####################################################################

SELECT datname AS "База данных",
       pg_encoding_to_char(encoding) AS "Кодировка",
       datcollate AS "Локаль сортировки",
       pg_size_pretty(pg_database_size(datname)) AS "Размер",
       shobj_description(oid, 'pg_database') AS "Комментарий"
FROM pg_database
WHERE datname = 'parking';

-- #####################################################################
-- ПУНКТ ЗАДАНИЯ 2: СОЗДАТЬ ТАБЛИЦЫ, ОПРЕДЕЛИТЬ ПОЛЯ И ТИПЫ ДАННЫХ
-- #####################################################################
-- 2.1. Девять таблиц базы данных и число полей в каждой

SELECT c.relname AS "Таблица",

     (SELECT count(*)
      FROM information_schema.columns col
      WHERE col.table_name = c.relname
           AND col.table_schema = 'public') AS "Полей",
       obj_description(c.oid) AS "Назначение"
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
     AND c.relkind = 'r'
ORDER BY c.relname;

-- 2.2. Поля и типы данных (на примере таблицы договоров)

SELECT ordinal_position AS "N",
       column_name AS "Поле",
                      CASE
                          WHEN character_maximum_length IS NOT NULL THEN data_type || '(' || character_maximum_length || ')'
                          WHEN data_type = 'numeric' THEN data_type || '(' || numeric_precision || ',' || numeric_scale || ')'
                          ELSE data_type
                      END AS "Тип данных",
                      is_nullable AS "Допускает NULL",
                      column_default AS "Значение по умолчанию"
FROM information_schema.columns
WHERE table_schema = 'public'
     AND table_name = 'contracts'
ORDER BY ordinal_position;

-- #####################################################################
-- ПУНКТ ЗАДАНИЯ 3: РЕАЛИЗОВАТЬ СВЯЗИ МЕЖДУ ТАБЛИЦАМИ
-- #####################################################################
-- 15 внешних ключей с правилами поддержания ссылочной целостности

SELECT conname AS "Внешний ключ",
       conrelid::regclass AS "Дочерняя таблица",
       confrelid::regclass AS "Родительская таблица",
       CASE confdeltype
           WHEN 'c' THEN 'CASCADE'
           WHEN 'n' THEN 'SET NULL'
           WHEN 'r' THEN 'RESTRICT'
           WHEN 'a' THEN 'NO ACTION'
       END AS "ON DELETE",
       CASE confupdtype
           WHEN 'c' THEN 'CASCADE'
           WHEN 'n' THEN 'SET NULL'
           WHEN 'r' THEN 'RESTRICT'
           WHEN 'a' THEN 'NO ACTION'
       END AS "ON UPDATE"
FROM pg_constraint
WHERE contype = 'f'
     AND connamespace = 'public'::regnamespace
ORDER BY conrelid::regclass::text,
         conname;

-- #####################################################################
-- ПУНКТ ЗАДАНИЯ 4: РЕАЛИЗОВАТЬ ОГРАНИЧЕНИЯ ЦЕЛОСТНОСТИ
-- #####################################################################
-- 4.1. Сводка: 51 ограничение трёх видов целостности

SELECT CASE contype
           WHEN 'p' THEN '1. Целостность по сущностям: PRIMARY KEY'
           WHEN 'u' THEN '1. Целостность по сущностям: UNIQUE'
           WHEN 'c' THEN '2. Семантическая целостность: CHECK'
           WHEN 'f' THEN '3. Ссылочная целостность: FOREIGN KEY'
       END AS "Вид целостности",
       count(*) AS "Ограничений"
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
GROUP BY contype
ORDER BY 1;

-- 4.2. Все ограничения с их определениями

SELECT conrelid::regclass AS "Таблица",
       conname AS "Ограничение",
       pg_get_constraintdef(oid) AS "Определение"
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
     AND contype IN ('c',
                     'u')
ORDER BY 1,
         2;

-- #####################################################################
-- ДОКАЗАТЕЛЬСТВО: ОГРАНИЧЕНИЯ ДЕЙСТВИТЕЛЬНО РАБОТАЮТ
-- Каждый запрос ниже должен завершиться ОШИБКОЙ
-- #####################################################################
 -- Целостность по сущностям: повтор государственного номера

INSERT INTO vehicles (veh_ID, veh_plate, veh_brand, veh_model, veh_color, veh_cat_ID, veh_client_ID)
VALUES (11, 'А123ВС55', 'Kia', 'Ceed', 'серый', 1, 2);

-- Семантическая целостность: скидка 50 % при допустимых 0..30

UPDATE clients
SET cl_discount = 50
WHERE cl_ID = 1;

-- Семантическая целостность: отрицательная сумма в квитанции

INSERT INTO payments (pay_ID, pay_receipt_no, pay_contr_ID, pay_emp_ID, pay_date, pay_sum, pay_method)
VALUES (17, 'КВ-000999', 1, 2, now(), -500.00, 'карта');

-- Ссылочная целостность: договор на несуществующего клиента № 99

INSERT INTO contracts (contr_ID, contr_number, contr_client_ID, contr_veh_ID, contr_place_ID, contr_tariff_ID, contr_emp_ID, contr_date, contr_start, contr_end, contr_amount, contr_status)
VALUES (11, 'Д-2024/011', 99, 10, 10, 3, 1, '2024-06-01', '2024-06-01', '2024-09-01', 13500.00, 'оформлен');

-- #####################################################################
-- ДОКАЗАТЕЛЬСТВО: БАЗА РАБОТАЕТ НА РЕАЛЬНЫХ ДАННЫХ
-- #####################################################################
-- Расчёты по договорам: начислено, оплачено частями, остаток долга

SELECT c.contr_number AS "Договор",
       cl.cl_name AS "Клиент",
       v.veh_plate AS "Госномер",
       p.pl_sector || '-' || p.pl_number AS "Место",
       c.contr_amount AS "Начислено",
       COALESCE(sum(pay.pay_sum), 0) AS "Оплачено",
       c.contr_amount - COALESCE(sum(pay.pay_sum), 0) AS "Долг",
       count(pay.pay_ID) AS "Квитанций"
FROM contracts c
JOIN clients cl ON cl.cl_ID = c.contr_client_ID
JOIN vehicles v ON v.veh_ID = c.contr_veh_ID
JOIN places p ON p.pl_ID = c.contr_place_ID
LEFT JOIN payments pay ON pay.pay_contr_ID = c.contr_ID
GROUP BY c.contr_ID,
         c.contr_number,
         cl.cl_name,
         v.veh_plate,
         p.pl_sector,
         p.pl_number,
         c.contr_amount
ORDER BY c.contr_number;

-- Журнал проездов: у незарегистрированных ТС клиент не определён

SELECT ps.pass_time AS "Время",
       ps.pass_direction AS "Направление",
       ps.pass_plate_raw AS "Номер с камеры",
       ps.pass_confidence AS "Достоверность",
       cl.cl_name AS "Клиент",
       ps.pass_gate AS "Ворота"
FROM passages ps
LEFT JOIN vehicles v ON v.veh_ID = ps.pass_veh_ID
LEFT JOIN clients cl ON cl.cl_ID = v.veh_client_ID
ORDER BY ps.pass_time;