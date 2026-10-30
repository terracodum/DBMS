-- =====================================================================
-- РГР. Вариант 11 — «Автостоянка»
-- Файл 4 из 7: ссылочная целостность
--   - внешние ключи и правила поддержания ссылочной целостности;
--   - ограничения-исключения (бизнес-правила предметной области);
--   - индексы по столбцам внешних ключей;
--   - комментарии к объектам базы данных.
-- Выполнять, подключившись к базе parking
-- =====================================================================

-----------------------------------------------------------------------
-- 1. Внешние ключи
-----------------------------------------------------------------------

-- Рекурсивная связь «руководитель — подчинённый».
-- SET NULL: увольнение руководителя не должно удалять его подчинённых
ALTER TABLE employees
ADD CONSTRAINT employees_FK FOREIGN KEY (emp_chief_ID)
REFERENCES employees (emp_ID)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Карточка ТС существует в базе только как имущество клиента
ALTER TABLE vehicles
ADD CONSTRAINT vehicles_FK1 FOREIGN KEY (veh_client_ID)
REFERENCES clients (cl_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Справочник: удалить категорию, по которой числятся ТС, запрещено
ALTER TABLE vehicles
ADD CONSTRAINT vehicles_FK2 FOREIGN KEY (veh_cat_ID)
REFERENCES vehicle_categories (cat_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

ALTER TABLE places
ADD CONSTRAINT places_FK FOREIGN KEY (pl_cat_ID)
REFERENCES vehicle_categories (cat_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

ALTER TABLE tariffs
ADD CONSTRAINT tariffs_FK FOREIGN KEY (tar_cat_ID)
REFERENCES vehicle_categories (cat_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- Договор не существует без заказчика
ALTER TABLE contracts
ADD CONSTRAINT contracts_FK1 FOREIGN KEY (contr_client_ID)
REFERENCES clients (cl_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Договор оформлен на конкретное транспортное средство
ALTER TABLE contracts
ADD CONSTRAINT contracts_FK2 FOREIGN KEY (contr_veh_ID)
REFERENCES vehicles (veh_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Машино-место, по которому есть история договоров, удалять запрещено
ALTER TABLE contracts
ADD CONSTRAINT contracts_FK3 FOREIGN KEY (contr_place_ID)
REFERENCES places (pl_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- Сохраняется тарифное условие, по которому рассчитана сумма договора
ALTER TABLE contracts
ADD CONSTRAINT contracts_FK4 FOREIGN KEY (contr_tariff_ID)
REFERENCES tariffs (tar_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- Финансовый документ не должен исчезать вместе с сотрудником
ALTER TABLE contracts
ADD CONSTRAINT contracts_FK5 FOREIGN KEY (contr_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- Квитанции — неотъемлемая часть договора
ALTER TABLE payments
ADD CONSTRAINT payments_FK1 FOREIGN KEY (pay_contr_ID)
REFERENCES contracts (contr_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE payments
ADD CONSTRAINT payments_FK2 FOREIGN KEY (pay_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- Факт проезда зафиксирован камерой и остаётся в журнале, даже если
-- карточка ТС, договор или машино-место удалены из базы
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
-- 2. Ограничения-исключения (EXCLUSION)
--    Бизнес-правила, которые нельзя выразить ограничениями
--    UNIQUE, CHECK или FOREIGN KEY
-----------------------------------------------------------------------
-- Расширение btree_gist позволяет использовать оператор = для целых
-- чисел в индексе типа GiST
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Одно машино-место не может быть занято двумя действующими договорами
-- с пересекающимися сроками
ALTER TABLE contracts
ADD CONSTRAINT contracts_EX_place
EXCLUDE USING gist (
    contr_place_ID WITH =,
    daterange(contr_start, contr_end, '[]') WITH &&
) WHERE (contr_status IN ('оформлен','действующий'));

-- Одно транспортное средство не может одновременно храниться
-- по двум действующим договорам
ALTER TABLE contracts
ADD CONSTRAINT contracts_EX_veh
EXCLUDE USING gist (
    contr_veh_ID WITH =,
    daterange(contr_start, contr_end, '[]') WITH &&
) WHERE (contr_status IN ('оформлен','действующий'));

-----------------------------------------------------------------------
-- 3. Индексы по столбцам внешних ключей
--    Объявление внешнего ключа не создаёт индекс автоматически,
--    поэтому для часто выполняемых соединений индексы создаются явно
-----------------------------------------------------------------------
CREATE INDEX vehicles_IX_client   ON vehicles  (veh_client_ID);
CREATE INDEX vehicles_IX_cat      ON vehicles  (veh_cat_ID);
CREATE INDEX contracts_IX_client  ON contracts (contr_client_ID);
CREATE INDEX contracts_IX_veh     ON contracts (contr_veh_ID);
CREATE INDEX contracts_IX_place   ON contracts (contr_place_ID);
CREATE INDEX contracts_IX_emp     ON contracts (contr_emp_ID);
CREATE INDEX payments_IX_contract ON payments  (pay_contr_ID);
CREATE INDEX payments_IX_emp      ON payments  (pay_emp_ID);
CREATE INDEX passages_IX_veh_time ON passages  (pass_veh_ID, pass_time);
CREATE INDEX passages_IX_plate    ON passages  (pass_plate_raw);

-----------------------------------------------------------------------
-- 4. Комментарии к объектам базы данных
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

COMMENT ON COLUMN clients.cl_type          IS 'Тип клиента: Ф — физическое лицо, Ю — юридическое лицо';
COMMENT ON COLUMN clients.cl_doc           IS 'Документ клиента: серия и номер паспорта или ИНН организации';
COMMENT ON COLUMN employees.emp_chief_ID   IS 'Руководитель сотрудника (рекурсивная связь)';
COMMENT ON COLUMN vehicles.veh_plate       IS 'Государственный регистрационный знак';
COMMENT ON COLUMN contracts.contr_end      IS 'Дата окончания срока действия; NULL — договор бессрочный';
COMMENT ON COLUMN payments.pay_sum         IS 'Сумма квитанции; договор может оплачиваться частями';
COMMENT ON COLUMN passages.pass_plate_raw  IS 'Строка госномера, распознанная камерой (сохраняется, даже если ТС не зарегистрировано)';
COMMENT ON COLUMN passages.pass_confidence IS 'Достоверность распознавания госномера, 0..1';
COMMENT ON COLUMN passages.pass_direction  IS 'Направление проезда: IN — въезд, OUT — выезд';
