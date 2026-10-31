-- ============================================================================
-- Лабораторная работа № 5 — запросы индивидуального задания (2.1–2.12)
-- Источник: lab5_parking_queries.ipynb
-- Подключение: parking.
-- Запуск: psql -X -v ON_ERROR_STOP=1 -d parking -f lab5_parking_queries.sql
-- Или откройте файл в Query Tool pgAdmin и выполните целиком.
-- Скрипт содержит явную транзакцию; после ошибки выполните ROLLBACK.
-- В конце ROLLBACK: учебные изменения не сохраняются.
-- ============================================================================

BEGIN;

-- 2.1. Все типы соединений

-- Запрос 2.1.1. INNER JOIN. Вывести договоры с именем клиента, госномером и маркой
-- транспортного средства.

SELECT c.contr_number AS "Договор",
       cl.cl_name     AS "Клиент",
       v.veh_plate    AS "Госномер",
       v.veh_brand    AS "Марка",
       c.contr_status AS "Статус"
FROM   contracts c
INNER  JOIN clients  cl ON cl.cl_ID  = c.contr_client_ID
INNER  JOIN vehicles v  ON v.veh_ID  = c.contr_veh_ID
ORDER  BY c.contr_ID;

-- Запрос 2.1.2. LEFT JOIN. Вывести все машино-места и договоры на них; места, на которые
-- договоры не оформлялись, выводятся с пустыми значениями.

SELECT p.pl_sector || '-' || p.pl_number AS "Место",
       p.pl_status                       AS "Статус места",
       c.contr_number                    AS "Договор"
FROM   places p
LEFT   JOIN contracts c ON c.contr_place_ID = p.pl_ID
ORDER  BY p.pl_ID;

-- Запрос 2.1.3. RIGHT JOIN. Вывести тот же список, поменяв таблицы местами: все машино-места
-- находятся справа от слова JOIN.

SELECT p.pl_sector || '-' || p.pl_number AS "Место",
       p.pl_status                       AS "Статус места",
       c.contr_number                    AS "Договор"
FROM   contracts c
RIGHT  JOIN places p ON c.contr_place_ID = p.pl_ID
ORDER  BY p.pl_ID;

-- Запрос 2.1.4. FULL JOIN. Сопоставить машино-места и действующие договоры: показать места без
-- действующего договора и договоры (завершённые, расторгнутые), которым не соответствует ни
-- одно место при этом условии.

SELECT p.pl_sector || '-' || p.pl_number AS "Место",
       c.contr_number                    AS "Действующий договор",
       c.contr_status                    AS "Статус"
FROM   places p
FULL   JOIN contracts c
       ON c.contr_place_ID = p.pl_ID AND c.contr_status = 'действующий'
ORDER  BY p.pl_ID, c.contr_ID;

-- Запрос 2.1.5. CROSS JOIN. Построить все сочетания категорий транспортных средств и периодов
-- тарификации.

SELECT vc.cat_name  AS "Категория",
       per.tar_period AS "Период"
FROM   vehicle_categories vc
CROSS  JOIN (SELECT DISTINCT tar_period FROM tariffs) per
ORDER  BY vc.cat_ID, per.tar_period;

-- Запрос 2.1.6. Рефлексивное соединение (самообъединение). Вывести сотрудников и их
-- непосредственных руководителей.

SELECT e.emp_name       AS "Сотрудник",
       e.emp_position   AS "Должность",
       ch.emp_name      AS "Руководитель"
FROM   employees e
LEFT   JOIN employees ch ON ch.emp_ID = e.emp_chief_ID
ORDER  BY e.emp_ID;

-- 2.2. DISTINCT

-- Запрос 2.2. Определить, какие марки транспортных средств хранятся на автостоянке, без
-- повторов.

SELECT DISTINCT veh_brand AS "Марка"
FROM   vehicles
ORDER  BY 1;

-- 2.3. BETWEEN

-- Запрос 2.3. Вывести договоры, оформленные в период с 1 марта по 30 апреля 2024 года
-- включительно.

SELECT contr_number AS "Договор",
       contr_date   AS "Дата оформления",
       contr_amount AS "Сумма",
       contr_status AS "Статус"
FROM   contracts
WHERE  contr_date BETWEEN '2024-03-01' AND '2024-04-30'
ORDER  BY contr_date;

-- 2.4. LIMIT

-- Запрос 2.4. Вывести три самые крупные квитанции об оплате.

SELECT pay_receipt_no AS "Квитанция",
       pay_date       AS "Дата",
       pay_sum        AS "Сумма",
       pay_method     AS "Способ оплаты"
FROM   payments
ORDER  BY pay_sum DESC
LIMIT  3;

-- 2.5. OFFSET

-- Запрос 2.5. Вывести квитанции, занимающие по сумме места с четвёртого по шестое (пропустить
-- три первые).

SELECT pay_receipt_no AS "Квитанция",
       pay_date       AS "Дата",
       pay_sum        AS "Сумма",
       pay_method     AS "Способ оплаты"
FROM   payments
ORDER  BY pay_sum DESC
LIMIT  3 OFFSET 3;

-- 2.6. LIKE, NOT LIKE

-- Запрос 2.6.1. LIKE. Найти клиентов — юридических лиц, названия которых начинаются с «ООО»
-- или «АО».

SELECT cl_ID AS "Код", cl_name AS "Клиент", cl_phone AS "Телефон"
FROM   clients
WHERE  cl_name LIKE 'ООО%' OR cl_name LIKE 'АО%'
ORDER  BY cl_ID;

-- Запрос 2.6.2. NOT LIKE. Найти клиентов, у которых указан адрес электронной почты не на
-- домене mail.ru.

SELECT cl_ID AS "Код", cl_name AS "Клиент", cl_email AS "Почта"
FROM   clients
WHERE  cl_email NOT LIKE '%@mail.ru'
ORDER  BY cl_ID;

-- 2.7. Регулярные выражения POSIX

-- Запрос 2.7.1. Оператор ~. Найти транспортные средства с госномерами региона 55 в формате
-- «буква, три цифры, две буквы, 55» (номера региона 155 не подходят).

SELECT veh_plate AS "Госномер", veh_brand AS "Марка", veh_model AS "Модель"
FROM   vehicles
WHERE  veh_plate ~ '^[А-Я][0-9]{3}[А-Я]{2}55$'
ORDER  BY veh_ID;

-- Запрос 2.7.2. Оператор ~* (без учёта регистра). Найти транспортные средства марок Kia,
-- Toyota и Honda.

SELECT veh_plate AS "Госномер", veh_brand AS "Марка", veh_model AS "Модель"
FROM   vehicles
WHERE  veh_brand ~* '^(kia|toyota|honda)$'
ORDER  BY veh_ID;

-- 2.8. Агрегатные функции

-- Запрос 2.8. Получить статистику по квитанциям: количество, общую сумму, среднюю, наименьшую
-- и наибольшую сумму платежа.

SELECT COUNT(*)                AS "Квитанций",
       SUM(pay_sum)            AS "Общая сумма",
       ROUND(AVG(pay_sum), 2)  AS "Средняя сумма",
       MIN(pay_sum)            AS "Наименьшая",
       MAX(pay_sum)            AS "Наибольшая"
FROM   payments;

-- 2.9. Вложенный запрос

-- Запрос 2.9. Вывести клиентов, у которых есть договор на сумму выше средней суммы всех
-- договоров.

SELECT cl_ID AS "Код", cl_name AS "Клиент"
FROM   clients
WHERE  cl_ID IN (SELECT contr_client_ID
                 FROM   contracts
                 WHERE  contr_amount > (SELECT AVG(contr_amount)
                                        FROM   contracts))
ORDER  BY cl_ID;

-- 2.10. CASE

-- Запрос 2.10. Разделить договоры по размеру суммы на группы «малый» (до 10 000), «средний»
-- (до 50 000) и «крупный».

SELECT contr_number AS "Договор",
       contr_amount AS "Сумма",
       CASE WHEN contr_amount < 10000 THEN 'малый'
            WHEN contr_amount < 50000 THEN 'средний'
            ELSE 'крупный'
       END          AS "Размер договора"
FROM   contracts
ORDER  BY contr_amount DESC;

-- 2.11. Группировка и простая сортировка

-- Запрос 2.11. Вывести число квитанций и сумму платежей по каждому способу оплаты,
-- отсортировав по убыванию суммы.

SELECT pay_method  AS "Способ оплаты",
       COUNT(*)    AS "Квитанций",
       SUM(pay_sum) AS "Сумма"
FROM   payments
GROUP  BY pay_method
ORDER  BY SUM(pay_sum) DESC;

-- 2.12. Группировка с условием и многоуровневая сортировка

-- Запрос 2.12. Вывести клиентов, оформивших не менее двух договоров или на общую сумму более
-- 25 000: число договоров и сумму. Сортировать по убыванию числа договоров, затем по убыванию
-- суммы, затем по имени.

SELECT cl.cl_name        AS "Клиент",
       COUNT(c.contr_ID) AS "Договоров",
       SUM(c.contr_amount) AS "Общая сумма"
FROM   clients cl
JOIN   contracts c ON c.contr_client_ID = cl.cl_ID
GROUP  BY cl.cl_ID, cl.cl_name
HAVING COUNT(c.contr_ID) >= 2 OR SUM(c.contr_amount) > 25000
ORDER  BY COUNT(c.contr_ID) DESC, SUM(c.contr_amount) DESC, cl.cl_name;

-- ---
-- Готово: все запросы выполнены.

ROLLBACK;
