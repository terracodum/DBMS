-- =====================================================================
-- Лабораторная работа № 4, п. 1 — учебный пример из пособия (стр. 91–100)
-- «Работа с массивами и типами JSON»
-- Выполнять, подключившись к базе данных parking
-- Запросы повторяют пример пособия; вместо сотрудников базы sales
-- используются сотрудники таблицы employees базы parking (id 1–4).
-- =====================================================================


-- #####################################################################
-- 1. МАССИВЫ: графики работы сотрудников (таблица schedules)
-- #####################################################################

CREATE TABLE schedules (
    sched_ID     integer NOT NULL,
    sched_emp_ID integer NOT NULL,
    schedule     integer[],
    CONSTRAINT schedules_PK PRIMARY KEY (sched_ID)
);

ALTER TABLE schedules
ADD CONSTRAINT schedules_FK FOREIGN KEY (sched_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Четыре графика (по одному для каждого сотрудника): номера дней недели
INSERT INTO schedules VALUES
    (1, 1, '{ 1, 3, 5, 6, 7 }'::integer[]),
    (2, 2, '{ 1, 2, 5, 7 }'::integer[]),
    (3, 3, '{ 2, 5 }'::integer[]),
    (4, 4, '{ 3, 5, 6 }'::integer[]);

SELECT schedules.sched_ID, employees.emp_name, schedules.schedule
FROM schedules JOIN employees
ON schedules.sched_emp_ID = employees.emp_ID;

-----------------------------------------
-- Каждый сотрудник должен работать 4 раза в неделю
-----------------------------------------

-- Сотруднику 4: добавить один день операцией конкатенации
UPDATE schedules
SET schedule = schedule || 7
WHERE sched_ID = 4;

-- Сотруднику 3: добавить день в конец массива (array_append)
UPDATE schedules
SET schedule = array_append(schedule, 6)
WHERE sched_ID = 3;

-- Сотруднику 3: добавить день в начало массива (array_prepend,
-- параметры функции поменялись местами)
UPDATE schedules
SET schedule = array_prepend(1, schedule)
WHERE sched_ID = 3;

-- Сотруднику 1: удалить из графика пятницу (array_remove)
UPDATE schedules
SET schedule = array_remove(schedule, 5)
WHERE sched_ID = 1;

-- Сотруднику 2: изменить дни работы по индексам элементов
-- (нумерация с единицы)
UPDATE schedules
SET schedule[1] = 2, schedule[2] = 3
WHERE sched_ID = 2;

-- То же самое срезом массива (slice); запрос возвращает прежний результат
UPDATE schedules
SET schedule[1:2] = ARRAY[2, 3]
WHERE sched_ID = 2;

SELECT * FROM schedules;

-----------------------------------------
-- Выборки из таблицы с массивами
-----------------------------------------

-- Сотрудники, работающие в среду (array_position — индекс первого
-- вхождения элемента или NULL)
SELECT * FROM schedules
WHERE array_position(schedule, 3) IS NOT NULL;

-- Сотрудники, работающие по понедельникам и воскресеньям
-- (@> — левый массив содержит все элементы правого)
SELECT * FROM schedules
WHERE schedule @> '{1, 7}'::integer[];

-- Работающие по вторникам и/или пятницам
-- (&& — у массивов есть общие элементы)
SELECT * FROM schedules
WHERE schedule && ARRAY[2, 5];

-- Не работающие ни во вторник, ни в пятницу
SELECT * FROM schedules
WHERE NOT (schedule && ARRAY[2, 5]);

-- Развернуть массив в столбец таблицы (unnest)
SELECT unnest(schedule) AS день_недели
FROM schedules
WHERE sched_emp_ID = 1;


-- #####################################################################
-- 2. JSON: увлечения сотрудников (таблица hobbies, связь «один-к-одному»)
-- #####################################################################

CREATE TABLE hobbies (
    hobb_emp_ID integer NOT NULL,
    hobbies     jsonb,
    CONSTRAINT hobbies_PK PRIMARY KEY (hobb_emp_ID)
);

ALTER TABLE hobbies
ADD CONSTRAINT hobbies_FK FOREIGN KEY (hobb_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

INSERT INTO hobbies VALUES
    (1, '{ "sports": ["волейбол", "плавание"],
           "home_lib": true, "trips": 3
         }'::jsonb ),
    (2, '{ "sports": ["теннис", "плавание"],
           "home_lib": true, "trips": 2
         }'::jsonb ),
    (3, '{ "sports": ["плавание"],
           "home_lib": false, "trips": 4
         }'::jsonb ),
    (4, '{ "sports": ["волейбол", "плавание", "теннис"],
           "home_lib": true, "trips": 0
         }'::jsonb );

SELECT * FROM hobbies;

-----------------------------------------
-- Выборки из таблицы с JSON
-----------------------------------------

-- Все, кто занимается волейболом
SELECT * FROM hobbies
WHERE hobbies @> '{"sports": ["волейбол"]}'::jsonb;

-- То же, но выводятся только виды спорта (-> — доступ к ключу)
SELECT hobb_emp_ID, hobbies -> 'sports' AS sports
FROM hobbies
WHERE hobbies -> 'sports' @> '[ "волейбол" ]'::jsonb;

-- Проверка наличия ключа (?): ключа «sport» нет — результат 0
SELECT count( * )
FROM hobbies
WHERE hobbies ? 'sport';

-- Ключ «sports» есть во всех строках — результат 4
SELECT count( * )
FROM hobbies
WHERE hobbies ? 'sports';

-----------------------------------------
-- Обновление JSON-объектов
-----------------------------------------

-- Сотрудник 4 решил заниматься только шахматами
UPDATE hobbies
SET hobbies = hobbies || '{"sports": ["шахматы"]}'
WHERE hobb_emp_ID = 4;

SELECT hobb_emp_ID, hobbies
FROM hobbies
WHERE hobb_emp_ID = 4;

-- Сотрудник 4 возобновил занятия плаванием: jsonb_set добавляет
-- элемент с номером 1 (нумерация с нуля) в массив sports
UPDATE hobbies
SET hobbies = jsonb_set(hobbies, '{ sports, 1 }','"плавание"')
WHERE hobb_emp_ID = 4;

SELECT hobb_emp_ID, hobbies
FROM hobbies
WHERE hobb_emp_ID = 4;
