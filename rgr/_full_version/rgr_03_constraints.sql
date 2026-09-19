-- =====================================================================
-- РГР. Вариант 11 — «Автостоянка»
-- Файл 3 из 7: целостность по сущностям и семантическая целостность
--   - ограничения уникальности (потенциальные ключи);
--   - значения по умолчанию;
--   - ограничения проверки CHECK.
-- Выполнять, подключившись к базе parking
-- =====================================================================

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

ALTER TABLE clients
ADD CONSTRAINT clients_CK_email
CHECK (cl_email IS NULL OR cl_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-zA-Z]{2,}$');

-- Сотрудники ----------------------------------------------------------
-- Сотрудник не может быть руководителем самого себя
ALTER TABLE employees
ADD CONSTRAINT employees_CK_chief
CHECK (emp_chief_ID IS NULL OR emp_chief_ID <> emp_ID);

-- Категории ТС --------------------------------------------------------
ALTER TABLE vehicle_categories
ADD CONSTRAINT categories_CK_coef CHECK (cat_coef > 0);

-- Транспортные средства -----------------------------------------------
-- Формат государственного регистрационного знака РФ: А123ВС55.
-- Допустимы только 12 букв кириллицы, имеющих латинские аналоги
-- по начертанию; код региона — 2 или 3 цифры.
ALTER TABLE vehicles
ADD CONSTRAINT vehicles_CK_plate
CHECK (veh_plate ~ '^[АВЕКМНОРСТУХ][0-9]{3}[АВЕКМНОРСТУХ]{2}[0-9]{2,3}$');

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
