-- =====================================================================
-- Лабораторная работа № 3 (РГР, вариант 11 — «Автостоянка»)
-- Создание и связывание таблиц базы данных в среде PostgreSQL
-- Выполнять после подключения к базе данных parking (\c parking)
-- =====================================================================
-- Содержание файла:
--   1. Создание таблиц                         (CREATE TABLE)
--   2. Целостность по сущностям                (UNIQUE)
--   3. Семантическая целостность               (DEFAULT, CHECK)
--   4. Ссылочная целостность                   (FOREIGN KEY)
--   5. Комментарии к таблицам                  (COMMENT)
--
-- Ограничения, кроме NOT NULL и PRIMARY KEY, добавляются отдельными
-- запросами ALTER TABLE: благодаря этому запрос CREATE TABLE проще
-- понять, а независимое определение ограничений облегчает их удаление
-- и модификацию.
-- =====================================================================


-- #####################################################################
-- 1. СОЗДАНИЕ ТАБЛИЦ
-- #####################################################################

-----------------------------------------
-- Справочник категорий транспортных средств
-----------------------------------------
CREATE TABLE vehicle_categories (
    cat_ID   integer NOT NULL,
    cat_name text NOT NULL,
    cat_coef numeric(4,2) NOT NULL,
    CONSTRAINT categories_PK PRIMARY KEY (cat_ID)
);

-----------------------------------------
-- Клиенты автостоянки
-----------------------------------------
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

-----------------------------------------
-- Сотрудники автостоянки
-----------------------------------------
CREATE TABLE employees (
    emp_ID        integer NOT NULL,
    emp_name      text NOT NULL,
    emp_position  text NOT NULL,
    emp_phone     varchar(20),
    emp_hire_date date NOT NULL,
    emp_chief_ID  integer,
    CONSTRAINT employees_PK PRIMARY KEY (emp_ID)
);

-----------------------------------------
-- Транспортные средства клиентов
-----------------------------------------
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

-----------------------------------------
-- Машино-места
-----------------------------------------
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

-----------------------------------------
-- Тарифы на услуги хранения
-----------------------------------------
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

-----------------------------------------
-- Договоры с клиентами
-----------------------------------------
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

-----------------------------------------
-- Квитанции об оплате услуг автостоянки
-- (допускается частичная оплата договора)
-----------------------------------------
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

-----------------------------------------
-- Журнал проездов
-- (электронная регистрация на въезде по госномеру)
-----------------------------------------
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


-- #####################################################################
-- 2-3. ЦЕЛОСТНОСТЬ ПО СУЩНОСТЯМ И СЕМАНТИЧЕСКАЯ ЦЕЛОСТНОСТЬ
-- #####################################################################

-----------------------------------------------------------------------
-- 1. Целостность по сущностям: потенциальные (альтернативные) ключи
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- 2. Семантическая целостность: значения по умолчанию
-----------------------------------------------------------------------
ALTER TABLE clients   ALTER COLUMN cl_discount  SET DEFAULT 0;
ALTER TABLE clients   ALTER COLUMN cl_reg_date  SET DEFAULT CURRENT_DATE;
ALTER TABLE places    ALTER COLUMN pl_status    SET DEFAULT 'свободно';
ALTER TABLE places    ALTER COLUMN pl_covered   SET DEFAULT false;
ALTER TABLE contracts ALTER COLUMN contr_date   SET DEFAULT CURRENT_DATE;
ALTER TABLE contracts ALTER COLUMN contr_status SET DEFAULT 'оформлен';
ALTER TABLE payments  ALTER COLUMN pay_date     SET DEFAULT now();
ALTER TABLE passages  ALTER COLUMN pass_time    SET DEFAULT now();

-----------------------------------------------------------------------
-- 3. Семантическая целостность: ограничения проверки CHECK
-----------------------------------------------------------------------

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


-- #####################################################################
-- 4-5. ССЫЛОЧНАЯ ЦЕЛОСТНОСТЬ И КОММЕНТАРИИ
-- #####################################################################

-----------------------------------------------------------------------
-- Рекурсивная связь «руководитель — подчинённый».
-- SET NULL: увольнение руководителя не должно удалять его подчинённых
-----------------------------------------------------------------------
ALTER TABLE employees
ADD CONSTRAINT employees_FK FOREIGN KEY (emp_chief_ID)
REFERENCES employees (emp_ID)
ON DELETE SET NULL
ON UPDATE CASCADE;

-----------------------------------------------------------------------
-- Транспортные средства
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Машино-места и тарифы
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Договоры: пять внешних ключей
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Квитанции об оплате
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Журнал проездов. Внешние ключи допускают значение NULL, поэтому
-- задано правило SET NULL: факт проезда зафиксирован камерой и должен
-- сохраняться, даже если карточка ТС, договор или машино-место удалены
-----------------------------------------------------------------------
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

-----------------------------------------------------------------------
-- Комментарии к таблицам
-----------------------------------------------------------------------
COMMENT ON TABLE vehicle_categories IS 'Справочник категорий транспортных средств';
COMMENT ON TABLE clients            IS 'Клиенты автостоянки (физические и юридические лица)';
COMMENT ON TABLE employees          IS 'Сотрудники автостоянки';
COMMENT ON TABLE vehicles           IS 'Транспортные средства клиентов';
COMMENT ON TABLE places             IS 'Машино-места';
COMMENT ON TABLE tariffs            IS 'Тарифы на услуги хранения';
COMMENT ON TABLE contracts          IS 'Договоры с клиентами';
COMMENT ON TABLE payments           IS 'Квитанции об оплате (допускается частичная оплата договора)';
COMMENT ON TABLE passages           IS 'Журнал проездов: электронная регистрация по государственному номеру';
