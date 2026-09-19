-- =====================================================================
-- РГР. Вариант 11 — «Автостоянка»
-- Файл 7 из 7: контроль структуры БД и проверка каскадных правил
-- Выполнять, подключившись к базе parking
-- Результаты этих запросов включаются в отчёт
-- =====================================================================

-----------------------------------------------------------------------
-- 1. Перечень таблиц базы данных
-----------------------------------------------------------------------
SELECT c.relname AS "Таблица",
       obj_description(c.oid) AS "Комментарий"
FROM   pg_class c
JOIN   pg_namespace n ON n.oid = c.relnamespace
WHERE  n.nspname = 'public' AND c.relkind = 'r'
ORDER  BY c.relname;

-----------------------------------------------------------------------
-- 2. Состав полей таблиц и их типы данных
-----------------------------------------------------------------------
SELECT table_name  AS "Таблица",
       ordinal_position AS "N",
       column_name AS "Поле",
       CASE WHEN character_maximum_length IS NOT NULL
                 THEN data_type || '(' || character_maximum_length || ')'
            WHEN numeric_precision IS NOT NULL AND data_type = 'numeric'
                 THEN data_type || '(' || numeric_precision || ',' || numeric_scale || ')'
            ELSE data_type END AS "Тип данных",
       is_nullable AS "NULL?",
       column_default AS "По умолчанию"
FROM   information_schema.columns
WHERE  table_schema = 'public'
ORDER  BY table_name, ordinal_position;

-----------------------------------------------------------------------
-- 3. Все ограничения целостности
-----------------------------------------------------------------------
SELECT conrelid::regclass AS "Таблица",
       conname            AS "Имя ограничения",
       CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                    WHEN 'u' THEN 'UNIQUE'
                    WHEN 'c' THEN 'CHECK'
                    WHEN 'f' THEN 'FOREIGN KEY'
                    WHEN 'x' THEN 'EXCLUDE' END AS "Тип",
       pg_get_constraintdef(oid) AS "Определение"
FROM   pg_constraint
WHERE  connamespace = 'public'::regnamespace
ORDER  BY 3, 1, 2;

-----------------------------------------------------------------------
-- 4. Сводка по количеству ограничений каждого вида
-----------------------------------------------------------------------
SELECT CASE contype WHEN 'p' THEN 'PRIMARY KEY (целостность по сущностям)'
                    WHEN 'u' THEN 'UNIQUE (потенциальные ключи)'
                    WHEN 'c' THEN 'CHECK (семантическая целостность)'
                    WHEN 'f' THEN 'FOREIGN KEY (ссылочная целостность)'
                    WHEN 'x' THEN 'EXCLUDE (бизнес-правила)' END AS "Вид ограничения",
       count(*) AS "Количество"
FROM   pg_constraint
WHERE  connamespace = 'public'::regnamespace
GROUP  BY contype
ORDER  BY 2 DESC;

-----------------------------------------------------------------------
-- 5. Связи между таблицами и правила поддержания
--    ссылочной целостности
-----------------------------------------------------------------------
SELECT conname             AS "Внешний ключ",
       conrelid::regclass  AS "Дочерняя таблица",
       confrelid::regclass AS "Родительская таблица",
       CASE confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
                        WHEN 'c' THEN 'CASCADE'   WHEN 'n' THEN 'SET NULL'
                        WHEN 'd' THEN 'SET DEFAULT' END AS "ON DELETE",
       CASE confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT'
                        WHEN 'c' THEN 'CASCADE'   WHEN 'n' THEN 'SET NULL'
                        WHEN 'd' THEN 'SET DEFAULT' END AS "ON UPDATE"
FROM   pg_constraint
WHERE  contype = 'f' AND connamespace = 'public'::regnamespace
ORDER  BY 2, 1;

-----------------------------------------------------------------------
-- 6. Индексы
-----------------------------------------------------------------------
SELECT tablename AS "Таблица", indexname AS "Индекс", indexdef AS "Определение"
FROM   pg_indexes
WHERE  schemaname = 'public'
ORDER  BY tablename, indexname;

-----------------------------------------------------------------------
-- 7. Проверка каскадных правил ссылочной целостности.
--    Выполняется в транзакции с откатом, поэтому данные не теряются.
-----------------------------------------------------------------------
BEGIN;

SELECT 'ДО удаления клиента' AS "Этап",
       (SELECT count(*) FROM vehicles  WHERE veh_client_ID = 1)   AS "ТС клиента 1",
       (SELECT count(*) FROM contracts WHERE contr_client_ID = 1) AS "Договоры клиента 1",
       (SELECT count(*) FROM payments) AS "Квитанций всего",
       (SELECT count(*) FROM passages WHERE pass_veh_ID IN (1, 9)) AS "Проезды его ТС";

DELETE FROM clients WHERE cl_ID = 1;

-- CASCADE: удалены ТС клиента, его договоры и связанные квитанции.
-- SET NULL: записи журнала проездов сохранены, ссылки обнулены.
SELECT 'ПОСЛЕ удаления клиента' AS "Этап",
       (SELECT count(*) FROM vehicles  WHERE veh_client_ID = 1)   AS "ТС клиента 1",
       (SELECT count(*) FROM contracts WHERE contr_client_ID = 1) AS "Договоры клиента 1",
       (SELECT count(*) FROM payments) AS "Квитанций всего",
       (SELECT count(*) FROM passages WHERE pass_plate_raw IN ('А123ВС55','С369МН155')) AS "Проезды сохранены";

SELECT pass_ID AS "Проезд", pass_plate_raw AS "Номер",
       pass_veh_ID AS "ТС", pass_contr_ID AS "Договор", pass_place_ID AS "Место"
FROM   passages
WHERE  pass_plate_raw IN ('А123ВС55','С369МН155')
ORDER  BY pass_ID;

ROLLBACK;

-----------------------------------------------------------------------
-- 7.1. Каскадное удаление через справочник категорий.
--      Удаление категории «Легковой» каскадно удаляет ТС этой
--      категории, машино-места, тарифы, а по цепочке — договоры
--      и квитанции. Выполняется в транзакции с откатом.
-----------------------------------------------------------------------
BEGIN;

SELECT 'ДО удаления категории' AS "Этап",
       (SELECT count(*) FROM vehicles)  AS "ТС",
       (SELECT count(*) FROM places)    AS "Мест",
       (SELECT count(*) FROM tariffs)   AS "Тарифов",
       (SELECT count(*) FROM contracts) AS "Договоров",
       (SELECT count(*) FROM payments)  AS "Квитанций";

DELETE FROM vehicle_categories WHERE cat_ID = 1;

SELECT 'ПОСЛЕ удаления категории' AS "Этап",
       (SELECT count(*) FROM vehicles)  AS "ТС",
       (SELECT count(*) FROM places)    AS "Мест",
       (SELECT count(*) FROM tariffs)   AS "Тарифов",
       (SELECT count(*) FROM contracts) AS "Договоров",
       (SELECT count(*) FROM payments)  AS "Квитанций";

ROLLBACK;

-----------------------------------------------------------------------
-- 8. Содержательные контрольные запросы к базе данных
-----------------------------------------------------------------------

-- 8.1. Состояние расчётов по договорам: начислено, оплачено, долг
SELECT c.contr_number AS "Договор",
       cl.cl_name     AS "Клиент",
       v.veh_plate    AS "Госномер",
       p.pl_sector || '-' || p.pl_number AS "Место",
       c.contr_amount AS "Начислено",
       COALESCE(sum(pay.pay_sum), 0) AS "Оплачено",
       c.contr_amount - COALESCE(sum(pay.pay_sum), 0) AS "Долг",
       count(pay.pay_ID) AS "Квитанций"
FROM   contracts c
JOIN   clients  cl ON cl.cl_ID = c.contr_client_ID
JOIN   vehicles v  ON v.veh_ID = c.contr_veh_ID
JOIN   places   p  ON p.pl_ID  = c.contr_place_ID
LEFT   JOIN payments pay ON pay.pay_contr_ID = c.contr_ID
GROUP  BY c.contr_ID, c.contr_number, cl.cl_name, v.veh_plate,
          p.pl_sector, p.pl_number, c.contr_amount
ORDER  BY c.contr_number;

-- 8.2. Журнал проездов с расшифровкой. Незарегистрированные ТС
--      видны как строки со значением NULL в столбце «Клиент»
SELECT ps.pass_time      AS "Время",
       ps.pass_direction AS "Направление",
       ps.pass_plate_raw AS "Распознанный номер",
       ps.pass_confidence AS "Достоверность",
       cl.cl_name        AS "Клиент",
       ps.pass_gate      AS "Ворота"
FROM   passages ps
LEFT   JOIN vehicles v  ON v.veh_ID = ps.pass_veh_ID
LEFT   JOIN clients  cl ON cl.cl_ID = v.veh_client_ID
ORDER  BY ps.pass_time;

-- 8.3. Структура подчинённости сотрудников (рекурсивная связь)
SELECT e.emp_name   AS "Сотрудник",
       e.emp_position AS "Должность",
       ch.emp_name  AS "Руководитель"
FROM   employees e
LEFT   JOIN employees ch ON ch.emp_ID = e.emp_chief_ID
ORDER  BY e.emp_ID;

-- 8.4. Занятость машино-мест действующими договорами
SELECT p.pl_sector || '-' || p.pl_number AS "Место",
       vc.cat_name  AS "Категория места",
       p.pl_status  AS "Статус",
       v.veh_plate  AS "Госномер ТС",
       c.contr_number AS "Договор",
       c.contr_start  AS "С",
       c.contr_end    AS "По"
FROM   places p
JOIN   vehicle_categories vc ON vc.cat_ID = p.pl_cat_ID
LEFT   JOIN contracts c ON c.contr_place_ID = p.pl_ID
                       AND c.contr_status IN ('оформлен','действующий')
LEFT   JOIN vehicles  v ON v.veh_ID = c.contr_veh_ID
ORDER  BY p.pl_sector, p.pl_number;
