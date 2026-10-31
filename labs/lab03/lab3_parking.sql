-- ============================================================================
-- Лабораторная работа № 3 — таблицы и данные автостоянки
-- Источник: lab3_parking.ipynb
-- Подключение: parking.
-- Запуск: psql -X -v ON_ERROR_STOP=1 -d parking -f lab3_parking.sql
-- Или откройте файл в Query Tool pgAdmin и выполните целиком.
-- Скрипт содержит явную транзакцию; после ошибки выполните ROLLBACK.
-- Создание таблиц рассчитано на первый запуск после предыдущих работ.
-- ============================================================================

BEGIN;

-- 1. Создание таблиц и ограничений

-- Лабораторная работа № 3 (РГР, вариант 11 — «Автостоянка»)
-- Создание и связывание таблиц базы данных в среде PostgreSQL
-- Выполнять после подключения к базе данных parking (\c parking)
-- Содержание файла:
-- 1. Создание таблиц                         (CREATE TABLE)
-- 2. Целостность по сущностям                (UNIQUE)
-- 3. Семантическая целостность               (DEFAULT, CHECK)
-- 4. Ссылочная целостность                   (FOREIGN KEY)
-- 5. Комментарии к таблицам                  (COMMENT)
-- Ограничения, кроме NOT NULL и PRIMARY KEY, добавляются отдельными
-- запросами ALTER TABLE: благодаря этому запрос CREATE TABLE проще
-- понять, а независимое определение ограничений облегчает их удаление
-- и модификацию.
-- 1. СОЗДАНИЕ ТАБЛИЦ
-- Справочник категорий транспортных средств

CREATE TABLE vehicle_categories (
    cat_ID   integer NOT NULL,
    cat_name text NOT NULL,
    cat_coef numeric(4,2) NOT NULL,
    CONSTRAINT categories_PK PRIMARY KEY (cat_ID)
);

-- Клиенты автостоянки

CREATE TABLE clients (
    cl_ID       integer NOT NULL,
    cl_type     char(1) NOT NULL,
    cl_name     text NOT NULL,
    cl_doc      varchar(20) NOT NULL,
    cl_phone    varchar(20) NOT NULL,
    cl_email    varchar(60),
    cl_discount integer NOT NULL,
    cl_reg_date date NOT NULL,
    CONSTRAINT clients_PK PRIMARY KEY (cl_ID)
);

-- Сотрудники автостоянки

CREATE TABLE employees (
    emp_ID        integer NOT NULL,
    emp_name      text NOT NULL,
    emp_position  text NOT NULL,
    emp_phone     varchar(20),
    emp_hire_date date NOT NULL,
    emp_chief_ID  integer,
    CONSTRAINT employees_PK PRIMARY KEY (emp_ID)
);

-- Транспортные средства клиентов

CREATE TABLE vehicles (
    veh_ID        integer NOT NULL,
    veh_plate     varchar(12) NOT NULL,
    veh_brand     text NOT NULL,
    veh_model     text NOT NULL,
    veh_color     text,
    veh_cat_ID    integer NOT NULL,
    veh_client_ID integer NOT NULL,
    CONSTRAINT vehicles_PK PRIMARY KEY (veh_ID)
);

-- Машино-места

CREATE TABLE places (
    pl_ID      integer NOT NULL,
    pl_sector  varchar(5) NOT NULL,
    pl_number  integer NOT NULL,
    pl_level   integer NOT NULL,
    pl_covered boolean NOT NULL,
    pl_cat_ID  integer NOT NULL,
    pl_status  text NOT NULL,
    CONSTRAINT places_PK PRIMARY KEY (pl_ID)
);

-- Тарифы на услуги хранения

CREATE TABLE tariffs (
    tar_ID        integer NOT NULL,
    tar_name      text NOT NULL,
    tar_period    text NOT NULL,
    tar_price     numeric(10,2) NOT NULL,
    tar_cat_ID    integer NOT NULL,
    tar_date_from date NOT NULL,
    tar_date_to   date,
    CONSTRAINT tariffs_PK PRIMARY KEY (tar_ID)
);

-- Договоры с клиентами

CREATE TABLE contracts (
    contr_ID        integer NOT NULL,
    contr_number    varchar(20) NOT NULL,
    contr_client_ID integer NOT NULL,
    contr_veh_ID    integer NOT NULL,
    contr_place_ID  integer NOT NULL,
    contr_tariff_ID integer NOT NULL,
    contr_emp_ID    integer NOT NULL,
    contr_date      date NOT NULL,
    contr_start     date NOT NULL,
    contr_end       date,
    contr_amount    numeric(10,2) NOT NULL,
    contr_status    text NOT NULL,
    CONSTRAINT contracts_PK PRIMARY KEY (contr_ID)
);

-- Квитанции об оплате услуг автостоянки
-- (допускается частичная оплата договора)

CREATE TABLE payments (
    pay_ID         integer NOT NULL,
    pay_receipt_no varchar(20) NOT NULL,
    pay_contr_ID   integer NOT NULL,
    pay_emp_ID     integer NOT NULL,
    pay_date       timestamp NOT NULL,
    pay_sum        numeric(10,2) NOT NULL,
    pay_method     text NOT NULL,
    pay_comment    text,
    CONSTRAINT payments_PK PRIMARY KEY (pay_ID)
);

-- Журнал проездов
-- (электронная регистрация на въезде по госномеру)

CREATE TABLE passages (
    pass_ID         integer NOT NULL,
    pass_veh_ID     integer,
    pass_contr_ID   integer,
    pass_place_ID   integer,
    pass_plate_raw  varchar(12) NOT NULL,
    pass_confidence numeric(4,3) NOT NULL,
    pass_direction  varchar(3) NOT NULL,
    pass_time       timestamp NOT NULL,
    pass_gate       varchar(10) NOT NULL,
    CONSTRAINT passages_PK PRIMARY KEY (pass_ID)
);

-- 2-3. ЦЕЛОСТНОСТЬ ПО СУЩНОСТЯМ И СЕМАНТИЧЕСКАЯ ЦЕЛОСТНОСТЬ
-- 1. Целостность по сущностям: потенциальные (альтернативные) ключи

ALTER TABLE vehicle_categories
ADD CONSTRAINT categories_UK UNIQUE (cat_name);

ALTER TABLE clients
ADD CONSTRAINT clients_UK UNIQUE (cl_doc);

-- Государственный регистрационный знак уникален: по нему работает
-- электронная регистрация на въезде

ALTER TABLE vehicles
ADD CONSTRAINT vehicles_UK UNIQUE (veh_plate);

-- Адрес машино-места «сектор + номер» уникален

ALTER TABLE places
ADD CONSTRAINT places_UK UNIQUE (pl_sector, pl_number);

ALTER TABLE tariffs
ADD CONSTRAINT tariffs_UK UNIQUE (tar_name, tar_cat_ID, tar_date_from);

ALTER TABLE contracts
ADD CONSTRAINT contracts_UK UNIQUE (contr_number);

ALTER TABLE payments
ADD CONSTRAINT payments_UK UNIQUE (pay_receipt_no);

-- Камера не может дважды зафиксировать один и тот же номер
-- в одном направлении в один и тот же момент времени

ALTER TABLE passages
ADD CONSTRAINT passages_UK UNIQUE (pass_plate_raw, pass_time, pass_direction);

-- 2. Семантическая целостность: значения по умолчанию

ALTER TABLE clients   ALTER COLUMN cl_discount  SET DEFAULT 0;

ALTER TABLE clients   ALTER COLUMN cl_reg_date  SET DEFAULT CURRENT_DATE;

ALTER TABLE places    ALTER COLUMN pl_status    SET DEFAULT 'свободно';

ALTER TABLE places    ALTER COLUMN pl_covered   SET DEFAULT false;

ALTER TABLE contracts ALTER COLUMN contr_date   SET DEFAULT CURRENT_DATE;

ALTER TABLE contracts ALTER COLUMN contr_status SET DEFAULT 'оформлен';

ALTER TABLE payments  ALTER COLUMN pay_date     SET DEFAULT now();

ALTER TABLE passages  ALTER COLUMN pass_time    SET DEFAULT now();

-- 3. Семантическая целостность: ограничения проверки CHECK
-- Клиенты -------------------------------------------------------------
-- Тип клиента: Ф — физическое лицо, Ю — юридическое лицо

ALTER TABLE clients
ADD CONSTRAINT clients_CK_type CHECK (cl_type IN ('Ф','Ю'));

-- Скидка постоянному клиенту не может превышать 30 %

ALTER TABLE clients
ADD CONSTRAINT clients_CK_discount CHECK (cl_discount BETWEEN 0 AND 30);

-- Сотрудники ----------------------------------------------------------
-- Сотрудник не может быть руководителем самого себя

ALTER TABLE employees
ADD CONSTRAINT employees_CK_chief
CHECK (emp_chief_ID IS NULL OR emp_chief_ID <> emp_ID);

-- Категории ТС --------------------------------------------------------

ALTER TABLE vehicle_categories
ADD CONSTRAINT categories_CK_coef CHECK (cat_coef > 0);

-- Транспортные средства -----------------------------------------------
-- Государственный регистрационный знак РФ содержит 8 символов
-- (А123ВС55) или 9 при трёхзначном коде региона (С369МН155)

ALTER TABLE vehicles
ADD CONSTRAINT vehicles_CK_plate
CHECK (length(veh_plate) BETWEEN 8 AND 9);

-- Машино-места --------------------------------------------------------

ALTER TABLE places
ADD CONSTRAINT places_CK_status
CHECK (pl_status IN ('свободно','занято','ремонт'));

ALTER TABLE places
ADD CONSTRAINT places_CK_level CHECK (pl_level BETWEEN -2 AND 10);

ALTER TABLE places
ADD CONSTRAINT places_CK_number CHECK (pl_number > 0);

-- Тарифы --------------------------------------------------------------

ALTER TABLE tariffs
ADD CONSTRAINT tariffs_CK_price CHECK (tar_price > 0);

ALTER TABLE tariffs
ADD CONSTRAINT tariffs_CK_period
CHECK (tar_period IN ('час','сутки','месяц'));

ALTER TABLE tariffs
ADD CONSTRAINT tariffs_CK_dates
CHECK (tar_date_to IS NULL OR tar_date_to >= tar_date_from);

-- Договоры ------------------------------------------------------------
-- Срок действия договора: дата окончания не раньше даты начала.
-- NULL в contr_end означает бессрочный договор

ALTER TABLE contracts
ADD CONSTRAINT contracts_CK_dates
CHECK (contr_end IS NULL OR contr_end >= contr_start);

-- Договор не может быть подписан позже начала срока хранения

ALTER TABLE contracts
ADD CONSTRAINT contracts_CK_signed CHECK (contr_date <= contr_start);

ALTER TABLE contracts
ADD CONSTRAINT contracts_CK_amount CHECK (contr_amount >= 0);

ALTER TABLE contracts
ADD CONSTRAINT contracts_CK_status
CHECK (contr_status IN ('оформлен','действующий','завершён','расторгнут'));

-- Квитанции об оплате -------------------------------------------------
-- Сумма платежа строго положительна

ALTER TABLE payments
ADD CONSTRAINT payments_CK_sum CHECK (pay_sum > 0);

ALTER TABLE payments
ADD CONSTRAINT payments_CK_method
CHECK (pay_method IN ('наличные','карта','перевод'));

-- Журнал проездов -----------------------------------------------------
-- Направление проезда: IN — въезд, OUT — выезд

ALTER TABLE passages
ADD CONSTRAINT passages_CK_dir CHECK (pass_direction IN ('IN','OUT'));

-- Достоверность распознавания госномера камерой: 0..1

ALTER TABLE passages
ADD CONSTRAINT passages_CK_conf
CHECK (pass_confidence >= 0 AND pass_confidence <= 1);

-- 4-5. ССЫЛОЧНАЯ ЦЕЛОСТНОСТЬ И КОММЕНТАРИИ
-- Рекурсивная связь «руководитель — подчинённый».
-- SET NULL: увольнение руководителя не должно удалять его подчинённых

ALTER TABLE employees
ADD CONSTRAINT employees_FK FOREIGN KEY (emp_chief_ID)
REFERENCES employees (emp_ID)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Транспортные средства

ALTER TABLE vehicles
ADD CONSTRAINT vehicles_FK1 FOREIGN KEY (veh_client_ID)
REFERENCES clients (cl_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE vehicles
ADD CONSTRAINT vehicles_FK2 FOREIGN KEY (veh_cat_ID)
REFERENCES vehicle_categories (cat_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Машино-места и тарифы

ALTER TABLE places
ADD CONSTRAINT places_FK FOREIGN KEY (pl_cat_ID)
REFERENCES vehicle_categories (cat_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE tariffs
ADD CONSTRAINT tariffs_FK FOREIGN KEY (tar_cat_ID)
REFERENCES vehicle_categories (cat_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Договоры: пять внешних ключей

ALTER TABLE contracts
ADD CONSTRAINT contracts_FK1 FOREIGN KEY (contr_client_ID)
REFERENCES clients (cl_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE contracts
ADD CONSTRAINT contracts_FK2 FOREIGN KEY (contr_veh_ID)
REFERENCES vehicles (veh_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE contracts
ADD CONSTRAINT contracts_FK3 FOREIGN KEY (contr_place_ID)
REFERENCES places (pl_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE contracts
ADD CONSTRAINT contracts_FK4 FOREIGN KEY (contr_tariff_ID)
REFERENCES tariffs (tar_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE contracts
ADD CONSTRAINT contracts_FK5 FOREIGN KEY (contr_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Квитанции об оплате

ALTER TABLE payments
ADD CONSTRAINT payments_FK1 FOREIGN KEY (pay_contr_ID)
REFERENCES contracts (contr_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE payments
ADD CONSTRAINT payments_FK2 FOREIGN KEY (pay_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Журнал проездов. Внешние ключи допускают значение NULL, поэтому
-- задано правило SET NULL: факт проезда зафиксирован камерой и должен
-- сохраняться, даже если карточка ТС, договор или машино-место удалены

ALTER TABLE passages
ADD CONSTRAINT passages_FK1 FOREIGN KEY (pass_veh_ID)
REFERENCES vehicles (veh_ID)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE passages
ADD CONSTRAINT passages_FK2 FOREIGN KEY (pass_contr_ID)
REFERENCES contracts (contr_ID)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE passages
ADD CONSTRAINT passages_FK3 FOREIGN KEY (pass_place_ID)
REFERENCES places (pl_ID)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Комментарии к таблицам

COMMENT ON TABLE vehicle_categories IS 'Справочник категорий транспортных средств';

COMMENT ON TABLE clients            IS 'Клиенты автостоянки (физические и юридические лица)';

COMMENT ON TABLE employees          IS 'Сотрудники автостоянки';

COMMENT ON TABLE vehicles           IS 'Транспортные средства клиентов';

COMMENT ON TABLE places             IS 'Машино-места';

COMMENT ON TABLE tariffs            IS 'Тарифы на услуги хранения';

COMMENT ON TABLE contracts          IS 'Договоры с клиентами';

COMMENT ON TABLE payments           IS 'Квитанции об оплате (допускается частичная оплата договора)';

COMMENT ON TABLE passages           IS 'Журнал проездов: электронная регистрация по государственному номеру';

-- 2. Заполнение и изменение данных

-- Лабораторная работа № 3 (РГР, вариант 11 — «Автостоянка»)
-- Вставка, удаление и обновление данных
-- Выполнять, подключившись к базе данных parking
-- Содержание файла:
-- 1. Вставка данных          (INSERT)
-- 2. Обновление данных       (UPDATE)
-- 3. Удаление данных         (DELETE)
-- Последовательность заполнения таблиц данными имеет значение:
-- вначале заполняются таблицы, соответствующие родительским отношениям
-- (находящимся со стороны «один» в связи «один-ко-многим»).
-- 1. ВСТАВКА ДАННЫХ
-- Категории транспортных средств

INSERT INTO vehicle_categories (cat_ID, cat_name, cat_coef)
     VALUES (1, 'Легковой',    1.00),
            (2, 'Внедорожник', 1.30),
            (3, 'Грузовой',    2.00),
            (4, 'Мотоцикл',    0.60);

-- Сотрудники (рекурсивная связь: руководитель — сотрудник 1)

INSERT INTO employees (emp_ID, emp_name, emp_position, emp_phone, emp_hire_date, emp_chief_ID)
     VALUES (1, 'Гордеев Пётр Ильич',      'администратор', '+79131110001', '2020-03-01', NULL),
            (2, 'Сомова Анна Львовна',     'кассир',        '+79131110002', '2021-06-15', 1),
            (3, 'Ким Дмитрий Сергеевич',   'кассир',        '+79131110003', '2022-02-01', 1),
            (4, 'Ветров Илья Романович',   'охранник',      '+79131110004', '2022-09-12', 1),
            (5, 'Пащенко Ольга Ивановна',  'охранник',      '+79131110005', '2023-04-03', 1);

-- Клиенты

INSERT INTO clients (cl_ID, cl_type, cl_name, cl_doc, cl_phone, cl_email, cl_discount, cl_reg_date)
     VALUES ( 1, 'Ф', 'Лебедев Игорь Олегович',      '5201 334567', '+79139990011', 'lebedev@mail.ru',   5,  '2024-01-10'),
            ( 2, 'Ф', 'Сафина Марина Рустамовна',    '5203 118842', '+79139990012', 'safina@yandex.ru',  0,  '2024-01-15'),
            ( 3, 'Ю', 'ООО «Сибтранс»',              '5503012345',  '+73812551020', 'office@sibtrans.ru',10, '2024-02-01'),
            ( 4, 'Ф', 'Круглов Антон Павлович',      '5204 556677', '+79139990014', NULL,                0,  '2024-02-20'),
            ( 5, 'Ф', 'Нечаева Елена Борисовна',     '5202 443311', '+79139990015', 'necheva@gmail.com', 5,  '2024-03-05'),
            ( 6, 'Ю', 'АО «Омскстрой»',              '5506078901',  '+73812445566', 'info@omskstroy.ru', 15, '2024-03-12'),
            ( 7, 'Ф', 'Тимофеев Роман Андреевич',    '5205 667788', '+79139990017', NULL,                0,  '2024-04-02'),
            ( 8, 'Ф', 'Жданова Полина Сергеевна',    '5206 223344', '+79139990018', 'zhdanova@mail.ru',  0,  '2024-04-18');

-- Транспортные средства

INSERT INTO vehicles (veh_ID, veh_plate, veh_brand, veh_model, veh_color, veh_cat_ID, veh_client_ID)
     VALUES ( 1, 'А123ВС55',  'Lada',       'Vesta',   'белый',     1, 1),
            ( 2, 'В456ЕК55',  'Kia',        'Rio',     'серый',     1, 2),
            ( 3, 'Е789МН55',  'ГАЗ',        'Газель',  'белый',     3, 3),
            ( 4, 'К321ОР55',  'Toyota',     'RAV4',    'чёрный',    2, 4),
            ( 5, 'М654СТ55',  'Hyundai',    'Solaris', 'синий',     1, 5),
            ( 6, 'Н987УХ55',  'КамАЗ',      '5320',    'оранжевый', 3, 6),
            ( 7, 'О147АВ55',  'Honda',      'CB500',   'красный',   4, 7),
            ( 8, 'Р258ЕК55',  'Renault',    'Duster',  'зелёный',   2, 8),
            ( 9, 'С369МН155', 'BMW',        'X5',      'чёрный',    2, 1),
            (10, 'Т741ОР55',  'Volkswagen', 'Polo',    'белый',     1, 2);

-- Машино-места

INSERT INTO places (pl_ID, pl_sector, pl_number, pl_level, pl_covered, pl_cat_ID, pl_status)
     VALUES ( 1, 'A', 1,  1, true,  1, 'занято'),
            ( 2, 'A', 2,  1, true,  1, 'занято'),
            ( 3, 'A', 3,  1, true,  1, 'свободно'),
            ( 4, 'A', 4,  1, true,  2, 'занято'),
            ( 5, 'A', 5,  1, true,  2, 'занято'),
            ( 6, 'B', 1,  0, false, 3, 'занято'),
            ( 7, 'B', 2,  0, false, 3, 'занято'),
            ( 8, 'B', 3,  0, false, 4, 'занято'),
            ( 9, 'C', 1, -1, true,  1, 'свободно'),
            (10, 'C', 2, -1, true,  1, 'свободно'),
            (11, 'C', 3, -1, true,  2, 'свободно'),
            (12, 'D', 1,  0, false, 1, 'ремонт');

-- Тарифы

INSERT INTO tariffs (tar_ID, tar_name, tar_period, tar_price, tar_cat_ID, tar_date_from, tar_date_to)
     VALUES (1, 'Часовой, легковой',      'час',     60.00, 1, '2024-01-01', NULL),
            (2, 'Суточный, легковой',     'сутки',  350.00, 1, '2024-01-01', NULL),
            (3, 'Месячный, легковой',     'месяц', 4500.00, 1, '2024-01-01', NULL),
            (4, 'Месячный, внедорожник',  'месяц', 5500.00, 2, '2024-01-01', NULL),
            (5, 'Месячный, грузовой',     'месяц', 9000.00, 3, '2024-01-01', NULL),
            (6, 'Месячный, мотоцикл',     'месяц', 2500.00, 4, '2024-01-01', NULL);

-- Договоры с клиентами

INSERT INTO contracts (contr_ID, contr_number, contr_client_ID, contr_veh_ID, contr_place_ID,
                       contr_tariff_ID, contr_emp_ID, contr_date, contr_start, contr_end,
                       contr_amount, contr_status)
     VALUES ( 1, 'Д-2024/001', 1,  1,  1, 3, 1, '2024-02-01', '2024-02-01', '2024-07-31', 25650.00, 'действующий'),
            ( 2, 'Д-2024/002', 2,  2,  2, 3, 2, '2024-02-05', '2024-02-05', '2024-08-04', 27000.00, 'действующий'),
            ( 3, 'Д-2024/003', 3,  3,  6, 5, 1, '2024-02-10', '2024-02-10', '2025-02-09', 97200.00, 'действующий'),
            ( 4, 'Д-2024/004', 4,  4,  4, 4, 2, '2024-02-20', '2024-03-01', '2024-08-31', 33000.00, 'действующий'),
            ( 5, 'Д-2024/005', 5,  5,  9, 3, 3, '2024-03-05', '2024-03-05', '2024-06-04', 12825.00, 'завершён'),
            ( 6, 'Д-2024/006', 6,  6,  7, 5, 1, '2024-03-12', '2024-03-15', '2025-03-14', 91800.00, 'действующий'),
            ( 7, 'Д-2024/007', 7,  7,  8, 6, 3, '2024-04-02', '2024-04-02', '2024-10-01', 15000.00, 'действующий'),
            ( 8, 'Д-2024/008', 8,  8, 11, 4, 2, '2024-04-18', '2024-04-20', '2024-07-19', 16500.00, 'расторгнут'),
            ( 9, 'Д-2024/009', 1,  9,  5, 4, 1, '2024-05-06', '2024-05-06', NULL,          5225.00, 'действующий'),
            (10, 'Д-2024/010', 2, 10,  3, 2, 3, '2024-05-15', '2024-05-15', '2024-05-25',  3500.00, 'завершён');

-- Квитанции об оплате (договор может оплачиваться частями)

INSERT INTO payments (pay_ID, pay_receipt_no, pay_contr_ID, pay_emp_ID, pay_date, pay_sum, pay_method, pay_comment)
     VALUES ( 1, 'КВ-000101',  1, 2, '2024-02-01 10:15', 10000.00, 'карта',    'первый взнос'),
            ( 2, 'КВ-000148',  1, 2, '2024-04-05 09:40', 10000.00, 'наличные', 'второй взнос'),
            ( 3, 'КВ-000190',  1, 3, '2024-06-01 12:05',  5650.00, 'перевод',  'окончательный расчёт'),
            ( 4, 'КВ-000112',  2, 2, '2024-02-05 11:20', 13500.00, 'карта',    'оплата за 3 месяца'),
            ( 5, 'КВ-000205',  2, 2, '2024-05-07 15:00', 13500.00, 'карта',    'оплата за 3 месяца'),
            ( 6, 'КВ-000120',  3, 3, '2024-02-10 09:05', 50000.00, 'перевод',  'аванс по договору'),
            ( 7, 'КВ-000260',  3, 3, '2024-08-12 10:30', 47200.00, 'перевод',  'окончательный расчёт'),
            ( 8, 'КВ-000131',  4, 2, '2024-02-20 14:45', 33000.00, 'карта',    'оплата в полном объёме'),
            ( 9, 'КВ-000155',  5, 3, '2024-03-05 10:00', 12825.00, 'наличные', 'оплата в полном объёме'),
            (10, 'КВ-000162',  6, 3, '2024-03-12 16:10', 45900.00, 'перевод',  'аванс 50 %'),
            (11, 'КВ-000178',  7, 3, '2024-04-02 09:50',  7500.00, 'наличные', 'первый взнос'),
            (12, 'КВ-000231',  7, 2, '2024-07-03 09:30',  7500.00, 'наличные', 'второй взнос'),
            (13, 'КВ-000186',  8, 2, '2024-04-18 13:25',  5500.00, 'карта',    'оплата за первый месяц'),
            (14, 'КВ-000199',  9, 2, '2024-05-06 08:40',  5225.00, 'карта',    'оплата за май'),
            (15, 'КВ-000240',  9, 3, '2024-06-05 08:35',  5225.00, 'карта',    'оплата за июнь'),
            (16, 'КВ-000210', 10, 3, '2024-05-15 17:05',  3500.00, 'наличные', 'посуточное хранение');

-- Журнал проездов (электронная регистрация по госномеру).
-- Записи 5, 6 и 16 относятся к незарегистрированному ТС и к
-- нераспознанному номеру: ссылки на ТС, договор и место равны NULL.

INSERT INTO passages (pass_ID, pass_veh_ID, pass_contr_ID, pass_place_ID,
                      pass_plate_raw, pass_confidence, pass_direction, pass_time, pass_gate)
     VALUES ( 1,    1,    1,    1, 'А123ВС55',  0.981, 'IN',  '2024-02-01 10:22', 'GATE-1'),
            ( 2,    1,    1,    1, 'А123ВС55',  0.975, 'OUT', '2024-02-01 19:05', 'GATE-2'),
            ( 3,    2,    2,    2, 'В456ЕК55',  0.964, 'IN',  '2024-02-05 11:40', 'GATE-1'),
            ( 4,    2,    2,    2, 'В456ЕК55',  0.958, 'OUT', '2024-02-05 20:11', 'GATE-2'),
            ( 5, NULL, NULL, NULL, 'Т777ТТ77',  0.642, 'IN',  '2024-02-05 12:03', 'GATE-1'),
            ( 6, NULL, NULL, NULL, 'Т777ТТ77',  0.655, 'OUT', '2024-02-05 12:40', 'GATE-2'),
            ( 7,    3,    3,    6, 'Е789МН55',  0.933, 'IN',  '2024-02-10 07:15', 'GATE-3'),
            ( 8,    3,    3,    6, 'Е789МН55',  0.921, 'OUT', '2024-02-10 18:47', 'GATE-3'),
            ( 9,    4,    4,    4, 'К321ОР55',  0.988, 'IN',  '2024-03-01 09:02', 'GATE-1'),
            (10,    4,    4,    4, 'К321ОР55',  0.979, 'OUT', '2024-03-01 21:33', 'GATE-2'),
            (11,    5,    5,    9, 'М654СТ55',  0.946, 'IN',  '2024-03-05 10:25', 'GATE-1'),
            (12,    5,    5,    9, 'М654СТ55',  0.939, 'OUT', '2024-03-05 22:10', 'GATE-2'),
            (13,    6,    6,    7, 'Н987УХ55',  0.902, 'IN',  '2024-03-15 06:40', 'GATE-3'),
            (14,    7,    7,    8, 'О147АВ55',  0.871, 'IN',  '2024-04-02 10:05', 'GATE-1'),
            (15,    8,    8,   11, 'Р258ЕК55',  0.957, 'IN',  '2024-04-20 12:30', 'GATE-1'),
            (16, NULL, NULL, NULL, '?258ЕК55',  0.418, 'OUT', '2024-04-20 23:12', 'GATE-2'),
            (17,    9,    9,    5, 'С369МН155', 0.968, 'IN',  '2024-05-06 08:55', 'GATE-1'),
            (18,   10,   10,    3, 'Т741ОР55',  0.952, 'IN',  '2024-05-15 17:20', 'GATE-1'),
            (19,    1,    1,    1, 'А123ВС55',  0.984, 'IN',  '2024-06-02 09:30', 'GATE-1'),
            (20,    1,    1,    1, 'А123ВС55',  0.977, 'OUT', '2024-06-02 18:58', 'GATE-2');

-- Контроль заполнения таблиц

SELECT 'vehicle_categories' AS "Таблица", count(*) AS "Строк" FROM vehicle_categories
UNION ALL SELECT 'clients',   count(*) FROM clients
UNION ALL SELECT 'employees', count(*) FROM employees
UNION ALL SELECT 'vehicles',  count(*) FROM vehicles
UNION ALL SELECT 'places',    count(*) FROM places
UNION ALL SELECT 'tariffs',   count(*) FROM tariffs
UNION ALL SELECT 'contracts', count(*) FROM contracts
UNION ALL SELECT 'payments',  count(*) FROM payments
UNION ALL SELECT 'passages',  count(*) FROM passages;

-- 2. ОБНОВЛЕНИЕ ДАННЫХ
-- ВНИМАНИЕ! Если не задать условие в секции WHERE,
-- то будут обновлены ВСЕ строки таблицы.
-- Клиенту Круглову А. П. предоставлена скидка 10 % как постоянному

UPDATE clients
   SET cl_discount = 10
 WHERE cl_ID = 4;

-- Клиент Тимофеев Р. А. сообщил новый номер телефона
-- и адрес электронной почты

UPDATE clients
   SET cl_phone = '+79139990077',
       cl_email = 'timofeev@mail.ru'
 WHERE cl_ID = 7;

-- Автомобиль перекрашен: изменяем цвет в карточке ТС

UPDATE vehicles
   SET veh_color = 'серебристый'
 WHERE veh_plate = 'М654СТ55';

-- Сотрудник Ким Д. С. повышен в должности

UPDATE employees
   SET emp_position = 'старший кассир'
 WHERE emp_ID = 3;

-- Тариф на хранение легковых автомобилей повышен на 10 %:
-- закрываем действие старого тарифа и вводим новый

UPDATE tariffs
   SET tar_date_to = '2024-12-31'
 WHERE tar_ID = 3;

INSERT INTO tariffs (tar_ID, tar_name, tar_period, tar_price, tar_cat_ID, tar_date_from, tar_date_to)
     VALUES (7, 'Месячный, легковой', 'месяц', 4950.00, 1, '2025-01-01', NULL);

-- Контроль выполненных обновлений

SELECT cl_ID AS "Код", cl_name AS "Клиент",
       cl_phone AS "Телефон", cl_discount AS "Скидка, %"
  FROM clients
 WHERE cl_ID IN (4, 7)
 ORDER BY cl_ID;

SELECT tar_ID AS "Код", tar_name AS "Тариф", tar_price AS "Цена",
       tar_date_from AS "Действует с", tar_date_to AS "по"
  FROM tariffs
 WHERE tar_cat_ID = 1 AND tar_period = 'месяц'
 ORDER BY tar_date_from;

-- 3. УДАЛЕНИЕ ДАННЫХ
-- ВНИМАНИЕ! При удалении данных необходимо учитывать ограничения
-- внешних ключей: для большинства связей задано правило ON DELETE
-- CASCADE, поэтому удаление родительской строки удаляет и зависимые
-- от неё строки дочерних таблиц.
-- Демонстрационные удаления выполняются внутри блока транзакции
-- и отменяются командой ROLLBACK, чтобы контрольный набор данных
-- остался неизменным.

SAVEPOINT deletion_demo;

-- 3.1. Удаление одной строки без зависимостей:
-- свободное машино-место C-2

DELETE FROM places
 WHERE pl_sector = 'C' AND pl_number = 2;

SELECT count(*) AS "Мест после удаления одного места" FROM places;

-- 3.2. Удаление строки с зависимостями: расторгнутый договор
-- Д-2024/008. Вместе с ним каскадно удаляется выписанная
-- по нему квитанция КВ-000186

SELECT count(*) AS "Квитанций до удаления договора" FROM payments;

DELETE FROM contracts
 WHERE contr_number = 'Д-2024/008';

SELECT count(*) AS "Квитанций после удаления договора" FROM payments;

-- 3.3. Удаление группы строк по условию:
-- события проезда с низкой достоверностью распознавания

DELETE FROM passages
 WHERE pass_confidence < 0.700;

SELECT count(*) AS "Записей журнала проездов" FROM passages;

-- Отмена всех выполненных удалений

ROLLBACK TO SAVEPOINT deletion_demo;

-- Контроль: данные восстановлены в исходное состояние

SELECT 'vehicle_categories' AS "Таблица", count(*) AS "Строк" FROM vehicle_categories
UNION ALL SELECT 'clients',   count(*) FROM clients
UNION ALL SELECT 'employees', count(*) FROM employees
UNION ALL SELECT 'vehicles',  count(*) FROM vehicles
UNION ALL SELECT 'places',    count(*) FROM places
UNION ALL SELECT 'tariffs',   count(*) FROM tariffs
UNION ALL SELECT 'contracts', count(*) FROM contracts
UNION ALL SELECT 'payments',  count(*) FROM payments
UNION ALL SELECT 'passages',  count(*) FROM passages;

COMMIT;
