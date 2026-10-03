-- =====================================================================
-- Лабораторная работа № 4 (РГР, вариант 11 — «Автостоянка»)
-- Столбцы с массивами и данными в формате JSON
-- Выполнять, подключившись к базе данных parking, после lab3_parking_data.sql
-- =====================================================================
-- Содержание файла:
--   1. Таблица со столбцом-массивом   (contract_options, text[])
--   2. Таблица со столбцом JSON       (passage_events, jsonb)
--   3. Заполнение таблиц данными      (INSERT)
--   4. Обработка данных в массивах
--   5. Обработка данных в JSON
-- =====================================================================


-- #####################################################################
-- 1. ТАБЛИЦА СО СТОЛБЦОМ-МАССИВОМ
-- #####################################################################
-- Дополнительные услуги по договору хранятся массивом строк, а не
-- отдельной таблицей «многие-ко-многим»: набор услуг невелик,
-- не имеет собственных атрибутов и всегда читается вместе с договором.
-- Связь с договором — «один-к-одному» (UNIQUE на внешний ключ).

CREATE TABLE contract_options (
    opt_ID       integer NOT NULL,
    opt_contr_ID integer NOT NULL,
    opt_services text[]  NOT NULL DEFAULT '{}',
    CONSTRAINT contract_options_PK PRIMARY KEY (opt_ID),
    CONSTRAINT contract_options_UK UNIQUE (opt_contr_ID),
    CONSTRAINT contract_options_FK FOREIGN KEY (opt_contr_ID)
        REFERENCES contracts (contr_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE contract_options IS
    'Дополнительные услуги по договору хранения (столбец-массив text[])';


-- #####################################################################
-- 2. ТАБЛИЦА СО СТОЛБЦОМ JSON
-- #####################################################################
-- Камера у шлагбаума присылает набор полей, состав которого меняется
-- (варианты распознавания, освещённость, скорость и т. д.), поэтому
-- «сырой» ответ хранится документом jsonb. Тип jsonb (а не json)
-- хранится в разобранном виде, поддерживает операторы @>, ?, ||, -
-- и индексы.

CREATE TABLE passage_events (
    ev_ID      integer NOT NULL,
    ev_pass_ID integer NOT NULL,
    ev_payload jsonb   NOT NULL,
    CONSTRAINT passage_events_PK PRIMARY KEY (ev_ID),
    CONSTRAINT passage_events_UK UNIQUE (ev_pass_ID),
    CONSTRAINT passage_events_FK FOREIGN KEY (ev_pass_ID)
        REFERENCES passages (pass_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE passage_events IS
    'Данные камеры по событию проезда (столбец JSON, тип jsonb)';


-- #####################################################################
-- 3. ЗАПОЛНЕНИЕ ТАБЛИЦ ДАННЫМИ
-- #####################################################################

-----------------------------------------
-- Дополнительные услуги по договорам (два способа записи массива:
-- конструктор ARRAY[...] и текстовый литерал '{...}')
-----------------------------------------
INSERT INTO contract_options (opt_ID, opt_contr_ID, opt_services)
     VALUES ( 1,  1, ARRAY['мойка', 'охрана']),
            ( 2,  2, ARRAY['мойка']),
            ( 3,  3, ARRAY['подогрев', 'охрана', 'мойка']),
            ( 4,  4, '{}'),
            ( 5,  5, '{"охрана"}'),
            ( 6,  6, '{"подогрев","шиномонтаж"}'),
            ( 7,  7, ARRAY['охрана']),
            ( 8,  8, '{}'),
            ( 9,  9, ARRAY['мойка', 'зарядка электромобиля']),
            (10, 10, '{}');

-----------------------------------------
-- Данные камер по проездам (в том числе по событиям с низкой
-- достоверностью — для них массив вариантов содержит несколько
-- кандидатов, а для проезда без вариантов — пустой массив)
-----------------------------------------
INSERT INTO passage_events (ev_ID, ev_pass_ID, ev_payload)
     VALUES ( 1,  1, '{"camera":"CAM-1","lighting":"day","speed_kmh":8,
                       "candidates":[{"plate":"А123ВС55","conf":0.981}]}'),
            ( 2,  2, '{"camera":"CAM-2","lighting":"evening","speed_kmh":11,
                       "candidates":[{"plate":"А123ВС55","conf":0.975}]}'),
            ( 3,  3, '{"camera":"CAM-1","lighting":"day","speed_kmh":9,
                       "candidates":[{"plate":"В456ЕК55","conf":0.964}]}'),
            ( 4,  5, '{"camera":"CAM-1","lighting":"day","speed_kmh":14,
                       "candidates":[{"plate":"Т777ТТ77","conf":0.642},
                                     {"plate":"Т777ТТ11","conf":0.311}]}'),
            ( 5,  7, '{"camera":"CAM-3","lighting":"dawn","speed_kmh":6,
                       "candidates":[{"plate":"Е789МН55","conf":0.933}]}'),
            ( 6, 10, '{"camera":"CAM-2","lighting":"night","speed_kmh":10,
                       "candidates":[{"plate":"К321ОР55","conf":0.979}]}'),
            ( 7, 13, '{"camera":"CAM-3","lighting":"dawn","speed_kmh":7,
                       "candidates":[{"plate":"Н987УХ55","conf":0.902},
                                     {"plate":"Н987УХ35","conf":0.288}]}'),
            ( 8, 16, '{"camera":"CAM-2","lighting":"night","speed_kmh":18,
                       "candidates":[]}'),
            ( 9, 17, '{"camera":"CAM-1","lighting":"day","speed_kmh":5,
                       "candidates":[{"plate":"С369МН155","conf":0.968}]}'),
            (10, 19, '{"camera":"CAM-1","lighting":"day","speed_kmh":8,
                       "candidates":[{"plate":"А123ВС55","conf":0.984}]}');

SELECT 'contract_options' AS "Таблица", count(*) AS "Строк" FROM contract_options
UNION ALL SELECT 'passage_events', count(*) FROM passage_events;


-- #####################################################################
-- 4. ОБРАБОТКА ДАННЫХ В СТОЛБЦЕ-МАССИВЕ
-- #####################################################################

-----------------------------------------
-- 4.1. Выборка договоров вместе с массивом услуг
--      и числом услуг в нём
-----------------------------------------
SELECT c.contr_number   AS "Договор",
       o.opt_services   AS "Услуги",
       coalesce(array_length(o.opt_services, 1), 0) AS "Число услуг"
  FROM contract_options o
  JOIN contracts c ON c.contr_ID = o.opt_contr_ID
 ORDER BY c.contr_ID;

-----------------------------------------
-- 4.2. Доступ к элементу по индексу (нумерация с 1)
-----------------------------------------
SELECT opt_contr_ID AS "Договор",
       opt_services[1] AS "Первая услуга"
  FROM contract_options
 WHERE opt_services[1] IS NOT NULL;

-----------------------------------------
-- 4.3. Поиск: договоры, в которых есть услуга «мойка»
--      (оператор ANY)
-----------------------------------------
SELECT opt_contr_ID AS "Договор", opt_services AS "Услуги"
  FROM contract_options
 WHERE 'мойка' = ANY (opt_services);

-----------------------------------------
-- 4.4. Поиск: договоры, содержащие обе услуги «охрана» и «мойка»
--      (оператор содержания @>)
-----------------------------------------
SELECT opt_contr_ID AS "Договор", opt_services AS "Услуги"
  FROM contract_options
 WHERE opt_services @> ARRAY['охрана', 'мойка'];

-----------------------------------------
-- 4.5. Развёртывание массива в строки (unnest) и подсчёт,
--      сколько договоров заказали каждую услугу
-----------------------------------------
SELECT s AS "Услуга", count(*) AS "Договоров"
  FROM contract_options, unnest(opt_services) AS s
 GROUP BY s
 ORDER BY count(*) DESC, s;

-----------------------------------------
-- 4.6. Добавление элемента в массив (array_append)
-----------------------------------------
UPDATE contract_options
   SET opt_services = array_append(opt_services, 'охрана')
 WHERE opt_contr_ID = 4;

-----------------------------------------
-- 4.7. Удаление элемента из массива (array_remove)
-----------------------------------------
UPDATE contract_options
   SET opt_services = array_remove(opt_services, 'мойка')
 WHERE opt_contr_ID = 3;

-----------------------------------------
-- 4.8. Замена массива целиком и объединение массивов (||)
-----------------------------------------
UPDATE contract_options
   SET opt_services = opt_services || ARRAY['мойка', 'подогрев']
 WHERE opt_contr_ID = 8;

SELECT opt_contr_ID AS "Договор", opt_services AS "Услуги после изменений"
  FROM contract_options
 WHERE opt_contr_ID IN (3, 4, 8)
 ORDER BY opt_contr_ID;


-- #####################################################################
-- 5. ОБРАБОТКА ДАННЫХ В СТОЛБЦЕ JSON
-- #####################################################################

-----------------------------------------
-- 5.1. Извлечение значений: -> возвращает JSON, ->> возвращает текст
-----------------------------------------
SELECT ev_pass_ID                           AS "Проезд",
       ev_payload ->> 'camera'              AS "Камера",
       ev_payload ->> 'lighting'            AS "Освещение",
       (ev_payload ->> 'speed_kmh')::int    AS "Скорость, км/ч"
  FROM passage_events
 ORDER BY ev_pass_ID;

-----------------------------------------
-- 5.2. Доступ к вложенным данным: первый вариант распознавания
--      номера (элемент массива candidates по индексу, нумерация с 0)
-----------------------------------------
SELECT ev_pass_ID AS "Проезд",
       ev_payload -> 'candidates' -> 0 ->> 'plate'              AS "Лучший вариант",
       (ev_payload -> 'candidates' -> 0 ->> 'conf')::numeric    AS "Достоверность"
  FROM passage_events
 ORDER BY ev_pass_ID;

-----------------------------------------
-- 5.3. Фильтрация по содержимому документа
--      (оператор @> — «JSON содержит фрагмент»)
-----------------------------------------
SELECT ev_pass_ID AS "Проезд", ev_payload ->> 'camera' AS "Камера"
  FROM passage_events
 WHERE ev_payload @> '{"lighting":"night"}';

-----------------------------------------
-- 5.4. Фильтрация по числовому значению внутри JSON:
--      проезды со скоростью выше 10 км/ч
-----------------------------------------
SELECT ev_pass_ID AS "Проезд", (ev_payload ->> 'speed_kmh')::int AS "Скорость, км/ч"
  FROM passage_events
 WHERE (ev_payload ->> 'speed_kmh')::int > 10;

-----------------------------------------
-- 5.5. Развёртывание вложенного массива в строки
--      (jsonb_array_elements): все варианты распознавания
-----------------------------------------
SELECT e.ev_pass_ID          AS "Проезд",
       c ->> 'plate'         AS "Вариант номера",
       (c ->> 'conf')::numeric AS "Достоверность"
  FROM passage_events e,
       jsonb_array_elements(e.ev_payload -> 'candidates') AS c
 ORDER BY e.ev_pass_ID, (c ->> 'conf')::numeric DESC;

-----------------------------------------
-- 5.6. Агрегирование по полю JSON: число проездов по камерам
-----------------------------------------
SELECT ev_payload ->> 'camera' AS "Камера", count(*) AS "Проездов"
  FROM passage_events
 GROUP BY ev_payload ->> 'camera'
 ORDER BY 1;

-----------------------------------------
-- 5.7. Изменение значения внутри JSON (jsonb_set)
-----------------------------------------
UPDATE passage_events
   SET ev_payload = jsonb_set(ev_payload, '{speed_kmh}', '10')
 WHERE ev_pass_ID = 1;

-----------------------------------------
-- 5.8. Добавление нового ключа (оператор || объединяет документы)
-----------------------------------------
UPDATE passage_events
   SET ev_payload = ev_payload || '{"verified":true}'
 WHERE (ev_payload -> 'candidates' -> 0 ->> 'conf')::numeric >= 0.9;

-----------------------------------------
-- 5.9. Удаление ключа из документа (оператор -)
-----------------------------------------
UPDATE passage_events
   SET ev_payload = ev_payload - 'lighting'
 WHERE ev_pass_ID = 19;

SELECT ev_pass_ID AS "Проезд", ev_payload AS "Документ после изменений"
  FROM passage_events
 WHERE ev_pass_ID IN (1, 5, 19)
 ORDER BY ev_pass_ID;
