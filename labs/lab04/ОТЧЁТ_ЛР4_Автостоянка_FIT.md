{{json
{
  "discipline": "Базы данных",
  "title": "Работа с массивами и типами JSON в PostgreSQL. Вариант 11 — «Автостоянка»",
  "student": {"name": "Харлова Никиты Станиславовича", "course": "3", "group": "ФИТ-242", "program": "02.03.02"},
  "teacher": {"title": "асс. Григор А.А.", "name": ""},
  "institution": {"short": "ОмГТУ", "department": "ПМиФИ", "year": "2026"},
  "work": {"type": "Лабораторная работа № 4"}
}
}}

# СОДЕРЖАНИЕ

# ВВЕДЕНИЕ

**Цель работы.**

Освоить хранение в таблицах значений составных типов: массивов переменной
длины и документов в формате JSON (тип `jsonb`), а также операции их
обработки.

**Задание.**

1. Изучить материал учебного пособия, стр. 90–100, выполнить учебный
   пример на стр. 91–100.
2. Согласно индивидуальному варианту РГР:
   - добавить таблицу со столбцом, содержащим массив значений;
   - добавить таблицу со столбцом, содержащим значения в формате JSON;
   - заполнить таблицы данными;
   - выполнить операции обработки данных в полях, содержащих массив и JSON.

# ОСНОВНАЯ ЧАСТЬ

## Учебный пример из пособия (стр. 91–100)

Скрипт: `lab4_textbook_example.sql`. В примере используется таблица
`employees`; в базе `parking` она содержит сотрудников с номерами 1–5,
поэтому запросы пособия выполняются без изменений.

### 1.1 Массивы: таблица `schedules`

Графики работы сотрудников (номера дней недели) хранятся в столбце
`schedule` типа `integer[]`. Одному сотруднику соответствует несколько
графиков, но каждый график связан с одним сотрудником.

Листинг: Создание таблицы schedules и вставка графиков

```sql
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

INSERT INTO schedules VALUES
    (1, 1, '{ 1, 3, 5, 6, 7 }'::integer[]),
    (2, 2, '{ 1, 2, 5, 7 }'::integer[]),
    (3, 3, '{ 2, 5 }'::integer[]),
    (4, 4, '{ 3, 5, 6 }'::integer[]);
```

Результат соединения с таблицей `employees`:

Листинг: Соединение таблиц schedules и employees

```sql
SELECT schedules.sched_ID, employees.emp_name, schedules.schedule
FROM schedules JOIN employees
ON schedules.sched_emp_ID = employees.emp_ID;
```

Таблица: Графики работы сотрудников с именами из таблицы employees

| sched_id | emp_name | schedule |
|---|---|---|
| 1 | Гордеев Пётр Ильич | {1,3,5,6,7} |
| 2 | Сомова Анна Львовна | {1,2,5,7} |
| 3 | Ким Дмитрий Сергеевич | {2,5} |
| 4 | Ветров Илья Романович | {3,5,6} |

**Обновление массивов.** Каждый сотрудник должен работать с заказами
четыре раза в неделю:

Таблица: Операции обновления массивов

| Операция | Запрос | Результат |
|---|---|---|
| Конкатенация (добавить день) | `UPDATE schedules SET schedule = schedule \|\| 7 WHERE sched_ID = 4;` | {3,5,6,7} |
| Добавить в конец, `array_append` | `UPDATE schedules SET schedule = array_append(schedule, 6) WHERE sched_ID = 3;` | {2,5,6} |
| Добавить в начало, `array_prepend` | `UPDATE schedules SET schedule = array_prepend(1, schedule) WHERE sched_ID = 3;` | {1,2,5,6} |
| Удалить элемент, `array_remove` | `UPDATE schedules SET schedule = array_remove(schedule, 5) WHERE sched_ID = 1;` | {1,3,6,7} |
| Изменение по индексам | `UPDATE schedules SET schedule[1] = 2, schedule[2] = 3 WHERE sched_ID = 2;` | {2,3,5,7} |
| Изменение срезом | `UPDATE schedules SET schedule[1:2] = ARRAY[2, 3] WHERE sched_ID = 2;` | {2,3,5,7} |

Содержимое таблицы после обновлений:

Таблица: Содержимое таблицы schedules после обновлений

| sched_id | sched_emp_id | schedule |
|---|---|---|
| 4 | 4 | {3,5,6,7} |
| 3 | 3 | {1,2,5,6} |
| 1 | 1 | {1,3,6,7} |
| 2 | 2 | {2,3,5,7} |

**Выборки.**

Таблица: Выборки из массивов

| Задача | Условие `WHERE` | Результат (sched_id) |
|---|---|---|
| Работают в среду | `array_position(schedule, 3) IS NOT NULL` | 4, 1, 2 |
| Работают по понедельникам и воскресеньям | `schedule @> '{1, 7}'::integer[]` | 1 |
| Работают по вторникам и/или пятницам | `schedule && ARRAY[2, 5]` | 4, 3, 2 |
| Не работают во вторник и пятницу | `NOT (schedule && ARRAY[2, 5])` | 1 |

Оператор `@>` проверяет, что в левом массиве содержатся все элементы
правого; `&&` — что у массивов есть общие элементы. Функция
`array_position` возвращает индекс первого вхождения элемента или `NULL`.

Развёртывание массива в столбец (`unnest`) для сотрудника 1:

Листинг: Развёртывание массива функцией unnest

```sql
SELECT unnest(schedule) AS день_недели
FROM schedules
WHERE sched_emp_ID = 1;
```

Результат: 1, 3, 6, 7.

### 1.2 JSON: таблица `hobbies`

Сведения об увлечениях сотрудников хранятся в столбце `hobbies` типа
`jsonb`. Связь с таблицей `employees` — «один-к-одному»: столбец
`hobb_emp_ID` одновременно первичный и внешний ключ.

Листинг: Создание таблицы hobbies и вставка данных

```sql
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
    (1, '{ "sports": ["волейбол", "плавание"], "home_lib": true, "trips": 3 }'::jsonb),
    (2, '{ "sports": ["теннис", "плавание"], "home_lib": true, "trips": 2 }'::jsonb),
    (3, '{ "sports": ["плавание"], "home_lib": false, "trips": 4 }'::jsonb),
    (4, '{ "sports": ["волейбол", "плавание", "теннис"], "home_lib": true, "trips": 0 }'::jsonb);
```

Порядок ключей в JSON-объектах не сохраняется: тип `jsonb` хранит документ
в разобранном виде.

**Выборки и операции.**

Таблица: Выборки и операции с JSON

| Задача | Запрос | Результат |
|---|---|---|
| Все волейболисты | `WHERE hobbies @> '{"sports": ["волейбол"]}'::jsonb` | сотрудники 1 и 4 |
| Только виды спорта | `SELECT hobb_emp_ID, hobbies -> 'sports' AS sports ... WHERE hobbies -> 'sports' @> '[ "волейбол" ]'::jsonb` | `["волейбол", "плавание"]`, `["волейбол", "плавание", "теннис"]` |
| Наличие ключа `sport` | `SELECT count(*) FROM hobbies WHERE hobbies ? 'sport'` | 0 |
| Наличие ключа `sports` | `SELECT count(*) FROM hobbies WHERE hobbies ? 'sports'` | 4 |

**Обновление JSON-объектов.** Сотрудник 4 решил заниматься только
шахматами:

Листинг: Замена вида спорта оператором ||

```sql
UPDATE hobbies
SET hobbies = hobbies || '{"sports": ["шахматы"]}'
WHERE hobb_emp_ID = 4;
```

Результат: `{"trips": 0, "sports": ["шахматы"], "home_lib": true}`.

Затем сотрудник 4 возобновил занятия плаванием. Функция `jsonb_set`
добавляет элемент с номером 1 (нумерация с нуля) в массив `sports`:

Листинг: Добавление элемента функцией jsonb_set

```sql
UPDATE hobbies
SET hobbies = jsonb_set(hobbies, '{ sports, 1 }','"плавание"')
WHERE hobb_emp_ID = 4;
```

Результат: `{"trips": 0, "sports": ["шахматы", "плавание"], "home_lib": true}`.

## Индивидуальное задание: вариант 11 «Автостоянка»

Скрипт: `lab4_parking_array_json.sql`. Выполняется на базе `parking` после
загрузки данных (`lab3_parking_data.sql`).

### 2.1 Таблица со столбцом-массивом: `contract_options`

Дополнительные услуги по договору хранения (мойка, охрана, подогрев и т. п.)
хранятся массивом строк в столбце `opt_services` типа `text[]`. Массив
выбран вместо отдельной таблицы «договор — услуга», потому что набор услуг
невелик, не имеет собственных атрибутов и всегда читается вместе с
договором. Связь с таблицей `contracts` — «один-к-одному» (ограничение
`UNIQUE` на внешнем ключе).

Листинг: Создание таблицы contract_options

```sql
CREATE TABLE contract_options (
    opt_ID       integer NOT NULL,
    opt_contr_ID integer NOT NULL,
    opt_services text[]  NOT NULL DEFAULT '{}',
    CONSTRAINT contract_options_PK PRIMARY KEY (opt_ID),
    CONSTRAINT contract_options_UK UNIQUE (opt_contr_ID),
    CONSTRAINT contract_options_FK FOREIGN KEY (opt_contr_ID)
        REFERENCES contracts (contr_ID) ON DELETE CASCADE ON UPDATE CASCADE
);
```

### 2.2 Таблица со столбцом JSON: `passage_events`

Камера у шлагбаума присылает набор полей, состав которого меняется
(варианты распознавания номера, освещённость, скорость), поэтому «сырой»
ответ камеры хранится документом в столбце `ev_payload` типа `jsonb`. Тип
`jsonb` выбран вместо `json`: он хранится в разобранном виде, поддерживает
операторы `@>`, `?`, `||`, `-` и индексирование. Связь с таблицей
`passages` — «один-к-одному».

Листинг: Создание таблицы passage_events

```sql
CREATE TABLE passage_events (
    ev_ID      integer NOT NULL,
    ev_pass_ID integer NOT NULL,
    ev_payload jsonb   NOT NULL,
    CONSTRAINT passage_events_PK PRIMARY KEY (ev_ID),
    CONSTRAINT passage_events_UK UNIQUE (ev_pass_ID),
    CONSTRAINT passage_events_FK FOREIGN KEY (ev_pass_ID)
        REFERENCES passages (pass_ID) ON DELETE CASCADE ON UPDATE CASCADE
);
```

### 2.3 Заполнение таблиц данными

В `contract_options` внесено 10 строк (по одной на каждый договор),
в `passage_events` — 10 строк. Массив записан двумя способами:
конструктором `ARRAY[...]` и текстовым литералом `'{...}'`; для договоров
без услуг — пустой массив `'{}'`. В документах по проездам с низкой
достоверностью распознавания содержится несколько вариантов номера, а
для одного проезда массив вариантов пуст.

Листинг: Заполнение таблиц данными (фрагмент)

```sql
INSERT INTO contract_options (opt_ID, opt_contr_ID, opt_services)
     VALUES ( 1,  1, ARRAY['мойка', 'охрана']),
            ( 2,  2, ARRAY['мойка']),
            ( 3,  3, ARRAY['подогрев', 'охрана', 'мойка']),
            ( 4,  4, '{}'),
            ...;

INSERT INTO passage_events (ev_ID, ev_pass_ID, ev_payload)
     VALUES ( 1,  1, '{"camera":"CAM-1","lighting":"day","speed_kmh":8,
                       "candidates":[{"plate":"А123ВС55","conf":0.981}]}'),
            ...;
```

Полный текст — в файле `lab4_parking_array_json.sql`, раздел 3.

### 2.4 Обработка данных в столбце-массиве

Таблица: Обработка данных в столбце-массиве

| № | Операция | Запрос (фрагмент) | Результат |
|---|---|---|---|
| 4.1 | Выборка с числом элементов | `array_length(opt_services, 1)` | по договорам: 2, 1, 3, 0, 1, 2, 1, 0, 2, 0 услуг |
| 4.2 | Элемент по индексу | `opt_services[1]` | первая услуга: мойка, мойка, подогрев, … |
| 4.3 | Поиск `ANY` | `'мойка' = ANY (opt_services)` | договоры 1, 2, 3, 9 |
| 4.4 | Содержание `@>` | `opt_services @> ARRAY['охрана','мойка']` | договоры 1, 3 |
| 4.5 | Развёртывание `unnest`, подсчёт | `SELECT s, count(*) FROM contract_options, unnest(opt_services) AS s GROUP BY s` | мойка — 4, охрана — 4, подогрев — 2, шиномонтаж — 1, зарядка электромобиля — 1 |
| 4.6 | Добавление `array_append` | `array_append(opt_services, 'охрана')` для договора 4 | `{охрана}` |
| 4.7 | Удаление `array_remove` | `array_remove(opt_services, 'мойка')` для договора 3 | `{подогрев,охрана}` |
| 4.8 | Объединение `\|\|` | `opt_services \|\| ARRAY['мойка','подогрев']` для договора 8 | `{мойка,подогрев}` |

### 2.5 Обработка данных в столбце JSON

Таблица: Обработка данных в столбце JSON

| № | Операция | Запрос (фрагмент) | Результат |
|---|---|---|---|
| 5.1 | Извлечение `->>` | `ev_payload ->> 'camera'`, `(ev_payload ->> 'speed_kmh')::int` | камера, освещение и скорость по 10 проездам |
| 5.2 | Вложенный доступ | `ev_payload -> 'candidates' -> 0 ->> 'plate'` | лучший вариант номера; для проезда 16 — NULL (вариантов нет) |
| 5.3 | Фильтр `@>` | `ev_payload @> '{"lighting":"night"}'` | проезды 10, 16 |
| 5.4 | Фильтр по числу | `(ev_payload ->> 'speed_kmh')::int > 10` | проезды 2, 5, 16 |
| 5.5 | Развёртывание массива `jsonb_array_elements` | `jsonb_array_elements(ev_payload -> 'candidates')` | 11 вариантов распознавания |
| 5.6 | Группировка по полю JSON | `GROUP BY ev_payload ->> 'camera'` | CAM-1 — 5, CAM-2 — 3, CAM-3 — 2 |
| 5.7 | Изменение значения `jsonb_set` | `jsonb_set(ev_payload, '{speed_kmh}', '10')` | скорость проезда 1: 8 → 10 |
| 5.8 | Добавление ключа `\|\|` | `ev_payload \|\| '{"verified":true}'` при достоверности ≥ 0,9 | ключ добавлен в документы проездов 1, 2, 3, 7, 10, 13, 17, 19 |
| 5.9 | Удаление ключа `-` | `ev_payload - 'lighting'` для проезда 19 | ключ `lighting` удалён |

## Схема базы данных

К схеме базы данных `parking`, показанной в отчёте по лабораторной работе № 2, добавлены четыре таблицы: `contract_options` и `passage_events` (задание 2), а также `schedules` и `hobbies` (учебный пример). Все четыре связаны с исходными таблицами внешними ключами с правилами `ON DELETE CASCADE ON UPDATE CASCADE`. Связи приведены в таблице 8. Обновлённую диаграмму можно получить в pgAdmin 4: **Tools → ERD Tool**, затем **ERD For Database** в контекстном меню базы `parking`.

Таблица: Таблицы, добавленные в лабораторной работе № 4

| Новая таблица | Родительская таблица | Тип связи | Тип столбца |
|---|---|---|---|
| schedules | employees | 1:M | `integer[]` |
| hobbies | employees | 1:1 | `jsonb` |
| contract_options | contracts | 1:1 | `text[]` |
| passage_events | passages | 1:1 | `jsonb` |

## Файлы работы

Таблица: Файлы работы

| Файл | Назначение |
|---|---|
| `lab4_textbook_example.sql` | учебный пример из пособия (`schedules`, `hobbies`) |
| `lab4_parking_array_json.sql` | индивидуальное задание (`contract_options`, `passage_events`) |

# ЗАКЛЮЧЕНИЕ

1. Изучены способы хранения составных значений в PostgreSQL: массивы
   (`integer[]`, `text[]`) и документы JSON (`jsonb`). Выполнен учебный
   пример: созданы таблицы `schedules` и `hobbies`, выполнены вставка,
   обновление и выборка данных.
2. Для варианта «Автостоянка» добавлены таблица `contract_options` со
   столбцом-массивом дополнительных услуг по договору и таблица
   `passage_events` со столбцом `jsonb` данных камеры по проездам; таблицы
   связаны с `contracts` и `passages` по принципу «один-к-одному».
3. Для обработки массивов использованы операторы и функции `ANY`, `@>`,
   `&&`, `||`, `array_length`, `array_append`, `array_prepend`,
   `array_remove`, `array_position`, `unnest`, обращение по индексу и срезу.
   Для JSON — операторы `->`, `->>`, `@>`, `?`, `||`, `-` и функции
   `jsonb_set`, `jsonb_array_elements`.
4. Массивы и JSON удобны для небольших списков и данных переменной структуры,
   но к значениям внутри них нельзя применить обычные внешние ключи, а
   проверка их корректности ложится на запросы. Строго структурированные
   данные (клиенты, договоры, платежи) по-прежнему хранятся в обычных
   таблицах.
