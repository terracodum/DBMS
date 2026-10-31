-- ============================================================================
-- Лабораторная работа № 5 — учебные примеры
-- Источник: lab5_textbook_example.ipynb
-- Подключение: parking.
-- Запуск: psql -X -v ON_ERROR_STOP=1 -d parking -f lab5_textbook_example.sql
-- Или откройте файл в Query Tool pgAdmin и выполните целиком.
-- Скрипт содержит явную транзакцию; после ошибки выполните ROLLBACK.
-- В конце ROLLBACK: учебные изменения не сохраняются.
-- ============================================================================

BEGIN;

-- 1. Отбор строк, сортировка, вычисляемые столбцы, DISTINCT, LIMIT, OFFSET, CASE

-- Запрос 1.1. Шаблон LIKE: выбрать все тарифы для легковых автомобилей

SELECT * FROM tariffs WHERE tar_name LIKE '%легковой%';

-- Запрос 1.2. Шаблон с символом «_»: найти марки транспортных средств, названия которых
-- состоят из четырёх символов

SELECT * FROM vehicles WHERE veh_brand LIKE '____';

-- Запрос 1.3. NOT LIKE: клиенты, адрес электронной почты которых не относится к доменам
-- mail.ru и yandex.ru

SELECT * FROM clients
WHERE cl_email NOT LIKE '%@mail.ru' AND
      cl_email NOT LIKE '%@yandex.ru';

-- Запрос 1.4. Регулярное выражение POSIX (~): выбрать транспортные средства марок Lada и Kia

SELECT * FROM vehicles WHERE veh_brand ~ '^(Lada|Kia)';

-- Запрос 1.5. Оператор !~: найти модели, названия которых не оканчиваются цифрой

SELECT * FROM vehicles WHERE veh_model !~ '[0-9]$';

-- Запрос 1.6. Предикат BETWEEN: найти тарифы в диапазоне цен от 4000 до 6000 руб.

SELECT * FROM tariffs WHERE tar_price BETWEEN 4000 AND 6000;

-- Запрос 1.7. Вычисляемый столбец: показать цену тарифа не только в рублях, но и в долларах
-- (условный курс 90 руб.)

SELECT tar_name, tar_price, round(tar_price/90, 2) AS USD
FROM tariffs;

-- Запрос 1.8. ORDER BY: список сотрудников в алфавитном порядке

SELECT * FROM employees ORDER BY emp_name ASC;

-- Запрос 1.9. DISTINCT: какого цвета транспортные средства стоят на автостоянке

SELECT DISTINCT veh_color FROM vehicles ORDER BY 1;

-- Запрос 1.10. LIMIT: найти три самых дорогих тарифа

SELECT tar_ID, tar_name, tar_price
FROM tariffs
ORDER BY tar_price DESC
LIMIT 3;

-- Запрос 1.11. OFFSET: найти следующие три тарифа, занимающие места с четвёртого по шестое

SELECT tar_ID, tar_name, tar_price
FROM tariffs
ORDER BY tar_price DESC
LIMIT 3 OFFSET 3;

-- Запрос 1.12. Условное выражение CASE: разделить месячные тарифы на категории «Дешёвый»,
-- «Средний», «Дорогой»

SELECT tar_name, tar_price,
       CASE WHEN tar_price <= 3000 THEN 'Дешёвый'
            WHEN tar_price <= 5000 THEN 'Средний'
            ELSE 'Дорогой'
       END AS Категория
FROM tariffs
WHERE tar_period = 'месяц'
ORDER BY tar_ID;

-- 2. Соединения

-- Запрос 1.2.1. Соединение через WHERE: номера договоров с именами клиентов (первые четыре
-- строки)

SELECT contracts.contr_number, clients.cl_name
FROM contracts, clients
WHERE contracts.contr_client_ID = clients.cl_ID
ORDER BY contracts.contr_ID
LIMIT 4;

-- Запрос 1.2.2. Соединение нескольких таблиц: к каким категориям относится транспортное
-- средство по договору с номером 3

SELECT vehicle_categories.cat_name
FROM vehicle_categories, vehicles, contracts
WHERE contracts.contr_ID = 3
  AND vehicle_categories.cat_ID = vehicles.veh_cat_ID
  AND contracts.contr_veh_ID = vehicles.veh_ID;

-- Запрос 1.2.3. Соединение JOIN ... ON (INNER JOIN): номера договоров с именами клиентов
-- (первые четыре строки)

SELECT contracts.contr_number, clients.cl_name
FROM contracts JOIN clients
ON contracts.contr_client_ID = clients.cl_ID
ORDER BY contracts.contr_ID
LIMIT 4;

-- Запрос 1.2.4. Соединение с группировкой: число транспортных средств в каждой категории

SELECT vehicles.veh_cat_ID AS "Код категории",
       COUNT(vehicles.veh_ID) AS "Число ТС"
FROM vehicle_categories JOIN vehicles
ON vehicle_categories.cat_ID = vehicles.veh_cat_ID
GROUP BY vehicles.veh_cat_ID
ORDER BY vehicles.veh_cat_ID;

-- 3. Внешние соединения

-- Запрос 1.3.0. Добавить в таблицу clients двух клиентов без договоров (потом их можно будет
-- удалить)

INSERT INTO clients (cl_ID, cl_type, cl_name, cl_doc, cl_phone, cl_email, cl_discount)
       VALUES (9,  'Ф', 'Сидоров Виктор Владимирович', '5207 100200', '+79139990019', NULL, 0),
              (10, 'Ф', 'Жуков Павел Денисович',       '5208 300400', '+79139990020', NULL, 0);

-- Запрос 1.3.1. Внутреннее соединение: список клиентов и оформленных ими договоров

SELECT c.cl_ID, c.cl_name, k.contr_ID
FROM clients c JOIN contracts k
ON c.cl_ID = k.contr_client_ID
ORDER BY c.cl_ID, k.contr_ID;

-- Запрос 1.3.2. Левое внешнее соединение: список клиентов и их договоров, включая клиентов без
-- договоров

SELECT c.cl_ID, c.cl_name, k.contr_ID
FROM clients c LEFT JOIN contracts k
ON c.cl_ID = k.contr_client_ID
ORDER BY c.cl_ID, k.contr_ID;

-- Запрос 1.3.3. Правое внешнее соединение: тот же результат, таблица clients — правая

SELECT c.cl_ID, c.cl_name, k.contr_ID
FROM contracts k RIGHT JOIN clients c
ON c.cl_ID = k.contr_client_ID
ORDER BY c.cl_ID, k.contr_ID;

-- Запрос 1.3.4. Полное внешнее соединение FULL JOIN: клиенты и договоры; результат совпадает с
-- правым соединением, так как каждый договор имеет клиента

SELECT c.cl_ID, c.cl_name, k.contr_ID
FROM clients c FULL JOIN contracts k
ON c.cl_ID = k.contr_client_ID
ORDER BY c.cl_ID, k.contr_ID;

-- Запрос 1.3.5. Список клиентов, которые не оформляли договоры (несовпадающие строки
-- возвращаются как NULL)

SELECT c.cl_ID, c.cl_name
FROM contracts k RIGHT OUTER JOIN clients c
ON c.cl_ID = k.contr_client_ID
WHERE k.contr_ID IS NULL;

-- Запрос 1.3.6. Удалить добавленных клиентов

DELETE FROM clients WHERE cl_ID IN (9, 10);

-- 4. Рефлексивные соединения

-- Запрос 1.4.1. Число подчинённых у каждого руководителя (рекурсивная связь emp_chief_ID —
-- emp_ID)

SELECT parents.emp_name AS руководитель,
       COUNT(children.emp_name) AS "число подчинённых"
FROM employees AS parents INNER JOIN employees AS children
ON parents.emp_ID = children.emp_chief_ID
GROUP BY руководитель
ORDER BY "число подчинённых" DESC;

-- Запрос 1.4.2. Определить, какие сотрудники занимают ту же должность, что и сотрудник «Ветров
-- Илья Романович»

SELECT e2.emp_name
FROM employees e1 JOIN employees e2
ON e1.emp_name = 'Ветров Илья Романович'
AND e1.emp_position = e2.emp_position;

-- 5. Вложенные запросы

-- Запрос 1.5.1. Некоррелированный вложенный запрос: названия и цены тарифов для категории
-- «Грузовой»

SELECT tar_name, tar_price
FROM tariffs
WHERE tar_cat_ID = (SELECT cat_ID
                    FROM vehicle_categories
                    WHERE cat_name = 'Грузовой')
ORDER BY tar_price;

-- Запрос 1.5.2. Вложенный запрос, возвращающий одно значение: категория, к которой относится
-- самый дорогой тариф

SELECT cat_name AS Категория
FROM vehicle_categories
WHERE cat_ID = (SELECT tar_cat_ID
                FROM tariffs
                WHERE tar_price = (SELECT MAX(tar_price)
                                   FROM tariffs));

-- Запрос 1.5.3. Ключевое слово ANY: имена клиентов, оформивших хотя бы один договор

SELECT cl_name
FROM clients
WHERE cl_ID = ANY(SELECT contr_client_ID FROM contracts);

-- Запрос 1.5.4. Ключевое слово ALL: платежи, сумма которых превышает среднюю сумму платежей по
-- каждому из договоров

SELECT pay_receipt_no, pay_sum
FROM payments
WHERE pay_sum > ALL(SELECT AVG(pay_sum) FROM payments
GROUP BY pay_contr_ID)
ORDER BY pay_sum;

-- Запрос 1.5.5. EXISTS: список клиентов, оформивших хотя бы один договор (переписанный запрос
-- 5.3)

SELECT cl_name
FROM clients
WHERE EXISTS(SELECT * FROM contracts
             WHERE contracts.contr_client_ID = clients.cl_ID);

-- Запрос 1.5.6. Коррелированный вложенный запрос: клиенты, оформившие больше одного договора
-- (кандидаты на скидку)

SELECT cl_ID, cl_name FROM clients c
WHERE 1 < (SELECT COUNT(k.contr_client_ID)
           FROM contracts k
           WHERE c.cl_ID = k.contr_client_ID);

-- 6. Пример выполнения задания (стр. 117)

-- Запрос 1.6.1. Многотабличный запрос: коды клиентов, оформивших два договора и более

SELECT clients.cl_ID, COUNT(contracts.contr_ID) AS total
FROM clients LEFT JOIN contracts
ON clients.cl_ID = contracts.contr_client_ID
GROUP BY clients.cl_ID
HAVING COUNT(contracts.contr_ID) >= 2
ORDER BY total DESC, clients.cl_ID ASC;

-- Запрос 1.6.2. Запрос с вложенным запросом: перечень машино-мест, на которые никогда не
-- оформлялись договоры

SELECT pl_ID, pl_sector, pl_number, pl_status
FROM places
WHERE NOT EXISTS
      (SELECT * FROM contracts
       WHERE contracts.contr_place_ID = places.pl_ID);

ROLLBACK;
