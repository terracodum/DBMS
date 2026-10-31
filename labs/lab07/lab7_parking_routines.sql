-- ============================================================================
-- Лабораторная работа № 7 — Функции и процедуры
-- Источник: lab7_parking_routines.ipynb
-- Подключение: parking.
-- Запуск: psql -X -v ON_ERROR_STOP=1 -d parking -f lab7_parking_routines.sql
-- Или откройте файл в Query Tool pgAdmin и выполните целиком.
-- Скрипт содержит явную транзакцию; после ошибки выполните ROLLBACK.
-- После ЛР3; повторный запуск поддерживается при неизменных определениях объектов.
-- ============================================================================

BEGIN;

-- Контроль исходных данных до любых демонстрационных изменений.
CREATE TEMP TABLE lab7_original_data (
    table_name text PRIMARY KEY,
    rows_json jsonb NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE t text; payload jsonb;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'vehicle_categories', 'clients', 'employees', 'vehicles', 'places',
        'tariffs', 'contracts', 'payments', 'passages'
    ] LOOP
        EXECUTE FORMAT(
            'SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text), ''[]''::jsonb) FROM public.%I r', t
        ) INTO payload;
        INSERT INTO pg_temp.lab7_original_data VALUES (t, payload);
    END LOOP;
END;
$$;

-- Подготовка схем
-- Учебные примеры отделены от трёх процедур и двух функций индивидуального задания.

CREATE SCHEMA IF NOT EXISTS lab7;
CREATE SCHEMA IF NOT EXISTS lab7_demo;

-- Учебные примеры со скалярным результатом
-- Адаптация стр. 124–125: присваивание результата SELECT через INTO и компактный RETURN. На
-- стр. 127 приведена функция SQL со скалярным результатом.

CREATE OR REPLACE FUNCTION lab7_demo.client_phone_into(p_client_id integer)
RETURNS text LANGUAGE plpgsql STABLE AS $$
DECLARE result text;
BEGIN
    SELECT cl_phone INTO result
    FROM public.clients WHERE cl_id = p_client_id;
    RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION lab7_demo.client_phone_direct(p_client_id integer)
RETURNS text LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN (SELECT cl_phone FROM public.clients WHERE cl_id = p_client_id);
END;
$$;

CREATE OR REPLACE FUNCTION lab7_demo.hello(p text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT 'Hello, ' || p || '!';
$$;

SELECT lab7_demo.client_phone_into(1) AS with_into,
       lab7_demo.client_phone_direct(1) AS direct_return,
       lab7_demo.hello('parking') AS greeting;

-- Учебные примеры с составным результатом
-- Адаптация стр. 125–128: составной тип, FOR с RETURN NEXT, SQL-функция с SETOF и SQL-функция
-- без SETOF. Автомобили заменяют товары пособия. Без SETOF возвращается только первая строка;
-- для прикладной выборки следует явно задавать требуемую кардинальность.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type t JOIN pg_namespace s ON s.oid = t.typnamespace
        WHERE s.nspname = 'lab7_demo' AND t.typname = 'vehicle_info'
    ) THEN
        CREATE TYPE lab7_demo.vehicle_info AS (code integer, plate text);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION lab7_demo.vehicle_loop()
RETURNS SETOF lab7_demo.vehicle_info LANGUAGE plpgsql STABLE AS $$
DECLARE v record;
BEGIN
    FOR v IN SELECT veh_id, veh_plate FROM public.vehicles ORDER BY veh_id
    LOOP
        RETURN NEXT ROW(v.veh_id, v.veh_plate)::lab7_demo.vehicle_info;
    END LOOP;
    RETURN;
END;
$$;

CREATE OR REPLACE FUNCTION lab7_demo.vehicle_sql()
RETURNS SETOF lab7_demo.vehicle_info LANGUAGE sql STABLE AS $$
    SELECT ROW(veh_id, veh_plate)::lab7_demo.vehicle_info
    FROM public.vehicles ORDER BY veh_id;
$$;

CREATE OR REPLACE FUNCTION lab7_demo.vehicle_first()
RETURNS lab7_demo.vehicle_info LANGUAGE sql STABLE AS $$
    SELECT ROW(veh_id, veh_plate)::lab7_demo.vehicle_info
    FROM public.vehicles ORDER BY veh_id;
$$;

SELECT * FROM lab7_demo.vehicle_loop() ORDER BY code LIMIT 5;

SELECT * FROM lab7_demo.vehicle_sql() ORDER BY code LIMIT 4;

SELECT * FROM lab7_demo.vehicle_first();

-- Процедура добавления клиента
-- Адаптация процедуры вставки на стр. 129. Добавляется физическое лицо с нулевой скидкой. Ключ
-- передаётся явно, как в исходной схеме. Ограничения таблицы проверяют уникальность документа
-- и допустимость полей. Процедуры вызываются через CALL и не выполняют собственный COMMIT.

CREATE OR REPLACE PROCEDURE lab7.client_insert(
    p_id integer, p_name text, p_doc text, p_phone text,
    p_reg_date date DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO public.clients (
        cl_id, cl_type, cl_name, cl_doc, cl_phone,
        cl_email, cl_discount, cl_reg_date
    ) VALUES (
        p_id, 'Ф', p_name, p_doc, p_phone, NULL, 0, p_reg_date
    );
END;
$$;

-- Процедура изменения контактов и скидки
-- Адаптация процедуры обновления на стр. 129. При отсутствии клиента возбуждается P0002.
-- Диапазон скидки 0–30 проверяет существующее ограничение таблицы; неверное значение вызывает
-- 23514.

CREATE OR REPLACE PROCEDURE lab7.client_update(
    p_id integer, p_phone text, p_email text, p_discount integer
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.clients
    SET cl_phone = p_phone, cl_email = p_email, cl_discount = p_discount
    WHERE cl_id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Клиент % не найден', p_id USING ERRCODE = 'P0002';
    END IF;
END;
$$;

-- Процедура удаления клиента без связанных данных
-- Адаптация процедуры удаления на стр. 130. Удаление допускается для клиента без автомобилей и
-- договоров. Для связанных клиентов процедура выдаёт 23503, чтобы не запускать каскадное
-- удаление финансовой истории. FOR UPDATE блокирует выбранного клиента до конца транзакции.
-- Правила внешних ключей исходной схемы не изменяются.

CREATE OR REPLACE PROCEDURE lab7.client_delete(p_id integer)
LANGUAGE plpgsql AS $$
DECLARE locked_id integer;
BEGIN
    SELECT cl_id INTO locked_id FROM public.clients
    WHERE cl_id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Клиент % не найден', p_id USING ERRCODE = 'P0002';
    END IF;
    IF EXISTS (SELECT 1 FROM public.vehicles WHERE veh_client_id = p_id)
       OR EXISTS (SELECT 1 FROM public.contracts WHERE contr_client_id = p_id)
    THEN
        RAISE EXCEPTION 'У клиента % есть связанные данные', p_id
            USING ERRCODE = '23503';
    END IF;
    DELETE FROM public.clients WHERE cl_id = p_id;
END;
$$;

-- Проверка трёх процедур
-- В savepoint создаётся отдельный учебный клиент, затем меняются его контакты и скидка, после
-- чего он удаляется. Тестовый код выбирается как MAX(cl_id)+100 в изолированном наборе данных;
-- это демонстрационный приём, а не генератор ключей для конкурентной работы. Уникальный
-- документ генерируется отдельно. После демонстрации savepoint отменяется.

-- Храним параметры демонстрации в таблице текущего сеанса.
-- MAX(id)+100 подходит для учебного запуска, но не для конкурентной выдачи ключей.
CREATE TEMP TABLE lab7_example_context ON COMMIT DROP AS
SELECT COALESCE(MAX(cl_id), 0) + 100 AS demo_id,
       COUNT(*) AS original_clients
FROM public.clients;

SAVEPOINT client_demo;

DO $$
DECLARE v_id integer;
BEGIN
    SELECT demo_id INTO v_id FROM pg_temp.lab7_example_context;
    CALL lab7.client_insert(
        v_id, 'Учебный клиент ЛР7',
        'ЛР7-' || LEFT(MD5(RANDOM()::text), 16),
        '+70000000000', DATE '2024-10-31'
    );
END;
$$;

SELECT cl_id, cl_name, cl_phone, cl_discount
FROM public.clients
WHERE cl_id = (SELECT demo_id FROM pg_temp.lab7_example_context);

DO $$
DECLARE v_id integer;
BEGIN
    SELECT demo_id INTO v_id FROM pg_temp.lab7_example_context;
    CALL lab7.client_update(v_id, '+70000000001', 'lab7@example.test', 10);
END;
$$;

SELECT cl_id, cl_phone, cl_email, cl_discount
FROM public.clients
WHERE cl_id = (SELECT demo_id FROM pg_temp.lab7_example_context);

DO $$
DECLARE v_id integer;
BEGIN
    SELECT demo_id INTO v_id FROM pg_temp.lab7_example_context;
    CALL lab7.client_delete(v_id);
END;
$$;

SELECT COUNT(*) AS demo_clients_after_delete
FROM public.clients
WHERE cl_id = (SELECT demo_id FROM pg_temp.lab7_example_context);

ROLLBACK TO SAVEPOINT client_demo;
RELEASE SAVEPOINT client_demo;

SELECT COUNT(*) AS restored_clients,
       (SELECT original_clients FROM pg_temp.lab7_example_context) AS expected_clients
FROM public.clients;

-- Функция расчёта остатка по договору
-- Функция PL/pgSQL возвращает сумму договора минус все его платежи. SELECT INTO STRICT требует
-- существования одного договора. Отрицательный остаток означает переплату; для отсутствующего
-- договора выдаётся P0002. STABLE указывает, что функция читает данные и не меняет их.

CREATE OR REPLACE FUNCTION lab7.contract_balance(p_contract_id integer)
RETURNS numeric LANGUAGE plpgsql STABLE AS $$
DECLARE
    amount numeric;
    paid numeric;
BEGIN
    SELECT contr_amount INTO STRICT amount
    FROM public.contracts WHERE contr_id = p_contract_id;
    SELECT COALESCE(SUM(pay_sum), 0) INTO paid
    FROM public.payments WHERE pay_contr_id = p_contract_id;
    RETURN amount - paid;
END;
$$;

SELECT contr_number, contr_amount,
       lab7.contract_balance(contr_id) AS balance
FROM public.contracts ORDER BY contr_id;

-- Функция выборки договоров клиента
-- SQL-функция возвращает таблицу договоров указанного клиента. Вызов находится в FROM; для
-- клиента без договоров возвращается пустое множество. Сортировка задаётся во внешнем запросе.

CREATE OR REPLACE FUNCTION lab7.client_contracts(p_client_id integer)
RETURNS TABLE (
    contract_id integer, contract_number text,
    amount numeric, status text
)
LANGUAGE sql STABLE AS $$
    SELECT contr_id, contr_number::text, contr_amount, contr_status
    FROM public.contracts WHERE contr_client_id = p_client_id;
$$;

SELECT * FROM lab7.client_contracts(1) ORDER BY contract_id;

-- Проверка ошибок и сохранности данных
-- Проверяются: неизвестный клиент, скидка вне диапазона, дублирование документа, попытка
-- удалить связанного клиента и запрос остатка неизвестного договора. Каждая ожидаемая ошибка
-- изолирована savepoint. Проверка сравнивает содержимое всех девяти исходных таблиц до и после
-- тестов.

-- Подблоки EXCEPTION откатывают ошибочную инструкцию автоматически.
DO $$
DECLARE
    v_missing_client integer;
    v_missing_contract integer;
    v_client integer;
    v_linked_client integer;
    v_doc text;
    v_phone text;
BEGIN
    SELECT demo_id INTO v_missing_client FROM pg_temp.lab7_example_context;
    SELECT COALESCE(MAX(contr_id), 0) + 100 INTO v_missing_contract
    FROM public.contracts;
    SELECT cl_id, cl_doc, cl_phone INTO STRICT v_client, v_doc, v_phone
    FROM public.clients ORDER BY cl_id LIMIT 1;
    SELECT contr_client_id INTO STRICT v_linked_client
    FROM public.contracts ORDER BY contr_id LIMIT 1;

    BEGIN
        CALL lab7.client_update(v_missing_client, v_phone, NULL, 0);
        RAISE EXCEPTION 'Не возникла ожидаемая ошибка P0002';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'P0002: клиент для изменения не найден';
    END;

    BEGIN
        CALL lab7.client_update(v_client, v_phone, NULL, 31);
        RAISE EXCEPTION 'Не возникла ожидаемая ошибка 23514';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '23514: скидка вне диапазона 0–30';
    END;

    BEGIN
        CALL lab7.client_insert(v_missing_client, 'Дубликат документа', v_doc, v_phone);
        RAISE EXCEPTION 'Не возникла ожидаемая ошибка 23505';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '23505: документ клиента должен быть уникальным';
    END;

    BEGIN
        CALL lab7.client_delete(v_linked_client);
        RAISE EXCEPTION 'Не возникла ожидаемая ошибка 23503';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE '23503: у клиента есть связанные данные';
    END;

    BEGIN
        CALL lab7.client_delete(v_missing_client);
        RAISE EXCEPTION 'Не возникла ожидаемая ошибка P0002';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'P0002: клиент для удаления не найден';
    END;

    BEGIN
        PERFORM lab7.contract_balance(v_missing_contract);
        RAISE EXCEPTION 'Не возникла ожидаемая ошибка P0002';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'P0002: договор для расчёта не найден';
    END;

    IF EXISTS (SELECT 1 FROM lab7.client_contracts(v_missing_client)) THEN
        RAISE EXCEPTION 'Для отсутствующего клиента ожидался пустой результат';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.contracts c
        LEFT JOIN public.payments p ON p.pay_contr_id = c.contr_id
        GROUP BY c.contr_id
        HAVING c.contr_amount - COALESCE(SUM(p.pay_sum), 0)
               IS DISTINCT FROM lab7.contract_balance(c.contr_id)
    ) THEN
        RAISE EXCEPTION 'Расчёт функции отличается от прямого запроса';
    END IF;
    RAISE NOTICE 'Ожидаемые ошибки и расчёты проверены';
END;
$$;

-- Состав сохранённых подпрограмм
-- В индивидуальной схеме lab7 должны находиться ровно три процедуры и две функции. Шесть
-- учебных функций и составной тип находятся отдельно в lab7_demo.

SELECT p.proname AS routine_name,
       CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS kind,
       l.lanname AS language
FROM pg_proc p
JOIN pg_namespace s ON s.oid = p.pronamespace
JOIN pg_language l ON l.oid = p.prolang
WHERE s.nspname = 'lab7'
ORDER BY kind DESC, routine_name;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM pg_proc p
        JOIN pg_namespace s ON s.oid = p.pronamespace
        WHERE s.nspname = 'lab7' AND p.prokind = 'p') <> 3
       OR (SELECT COUNT(*) FROM pg_proc p
           JOIN pg_namespace s ON s.oid = p.pronamespace
           WHERE s.nspname = 'lab7' AND p.prokind = 'f') <> 2 THEN
        RAISE EXCEPTION 'Ожидались три процедуры и две функции';
    END IF;
END;
$$;

DO $$
DECLARE saved record; current_rows jsonb;
BEGIN
    FOR saved IN SELECT * FROM pg_temp.lab7_original_data LOOP
        EXECUTE FORMAT(
            'SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text), ''[]''::jsonb) FROM public.%I r', saved.table_name
        ) INTO current_rows;
        IF current_rows IS DISTINCT FROM saved.rows_json THEN
            RAISE EXCEPTION 'Изменились данные таблицы %', saved.table_name;
        END IF;
    END LOOP;
    RAISE NOTICE 'Данные всех девяти исходных таблиц сохранены';
END;
$$;

COMMIT;
