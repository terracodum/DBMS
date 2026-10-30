-- =====================================================================
-- РГР. Вариант 11 — «Автостоянка»
-- Файл 6 из 7: проверка работы ограничений целостности
-- Выполнять, подключившись к базе parking, ПОСЛЕ загрузки данных
-- =====================================================================
-- Каждая инструкция этого файла должна ЗАВЕРШИТЬСЯ ОШИБКОЙ — это и есть
-- подтверждение того, что ограничения целостности работают.
-- В pgAdmin инструкции выполняются по одной (выделить и нажать F5),
-- текст ошибки — на вкладке Messages.
-- =====================================================================

-- ТЕСТ 1. Целостность по сущностям: попытка вставить транспортное
--         средство с уже существующим государственным номером.
-- Ожидается: нарушение ограничения уникальности "vehicles_uk"
INSERT INTO vehicles (veh_ID, veh_plate, veh_brand, veh_model, veh_color, veh_cat_ID, veh_client_ID)
     VALUES (11, 'А123ВС55', 'Kia', 'Ceed', 'серый', 1, 2);

-- ТЕСТ 2. Целостность по сущностям: повторное значение первичного ключа.
-- Ожидается: нарушение ограничения уникальности "clients_pk"
INSERT INTO clients (cl_ID, cl_type, cl_name, cl_doc, cl_phone, cl_discount, cl_reg_date)
     VALUES (1, 'Ф', 'Иванов Иван Иванович', '5299 000000', '+79130000000', 0, '2024-06-01');

-- ТЕСТ 3. Семантическая целостность: госномер недопустимой длины.
-- Ожидается: нарушение ограничения-проверки "vehicles_ck_plate"
INSERT INTO vehicles (veh_ID, veh_plate, veh_brand, veh_model, veh_color, veh_cat_ID, veh_client_ID)
     VALUES (12, 'А12ВС5', 'Kia', 'Ceed', 'серый', 1, 2);

-- ТЕСТ 4. Семантическая целостность: скидка больше допустимой.
-- Ожидается: нарушение ограничения-проверки "clients_ck_discount"
UPDATE clients SET cl_discount = 50 WHERE cl_ID = 1;

-- ТЕСТ 5. Семантическая целостность: отрицательная сумма квитанции.
-- Ожидается: нарушение ограничения-проверки "payments_ck_sum"
INSERT INTO payments (pay_ID, pay_receipt_no, pay_contr_ID, pay_emp_ID, pay_date, pay_sum, pay_method)
     VALUES (17, 'КВ-000999', 1, 2, now(), -500.00, 'карта');

-- ТЕСТ 6. Семантическая целостность: недопустимый способ оплаты.
-- Ожидается: нарушение ограничения-проверки "payments_ck_method"
INSERT INTO payments (pay_ID, pay_receipt_no, pay_contr_ID, pay_emp_ID, pay_date, pay_sum, pay_method)
     VALUES (18, 'КВ-000998', 1, 2, now(), 1000.00, 'криптовалюта');

-- ТЕСТ 7. Семантическая целостность: дата окончания договора
--         раньше даты его начала.
-- Ожидается: нарушение ограничения-проверки "contracts_ck_dates"
UPDATE contracts SET contr_end = '2024-01-01' WHERE contr_ID = 1;

-- ТЕСТ 8. Семантическая целостность: сотрудник назначен руководителем
--         самого себя.
-- Ожидается: нарушение ограничения-проверки "employees_ck_chief"
UPDATE employees SET emp_chief_ID = 2 WHERE emp_ID = 2;

-- ТЕСТ 9. Семантическая целостность: недопустимое направление проезда.
-- Ожидается: нарушение ограничения-проверки "passages_ck_dir"
INSERT INTO passages (pass_ID, pass_veh_ID, pass_contr_ID, pass_place_ID,
                      pass_plate_raw, pass_confidence, pass_direction, pass_time, pass_gate)
     VALUES (21, 1, 1, 1, 'А123ВС55', 0.95, 'UP', now(), 'GATE-1');

-- ТЕСТ 10. Семантическая целостность: недопустимое значение
--          достоверности распознавания (должно быть от 0 до 1).
-- Ожидается: нарушение ограничения-проверки "passages_ck_conf"
INSERT INTO passages (pass_ID, pass_veh_ID, pass_contr_ID, pass_place_ID,
                      pass_plate_raw, pass_confidence, pass_direction, pass_time, pass_gate)
     VALUES (22, 1, 1, 1, 'А123ВС55', 1.500, 'IN', now(), 'GATE-1');

-- ТЕСТ 11. Ссылочная целостность: договор на несуществующего клиента.
-- Ожидается: нарушение ограничения внешнего ключа "contracts_fk1"
INSERT INTO contracts (contr_ID, contr_number, contr_client_ID, contr_veh_ID, contr_place_ID,
                       contr_tariff_ID, contr_emp_ID, contr_date, contr_start, contr_end,
                       contr_amount, contr_status)
     VALUES (11, 'Д-2024/011', 99, 10, 10, 3, 1, '2024-06-01', '2024-06-01', '2024-09-01', 13500.00, 'оформлен');

-- ТЕСТ 12. Ссылочная целостность: квитанция по несуществующему договору.
-- Ожидается: нарушение ограничения внешнего ключа "payments_fk1"
INSERT INTO payments (pay_ID, pay_receipt_no, pay_contr_ID, pay_emp_ID, pay_date, pay_sum, pay_method)
     VALUES (19, 'КВ-000997', 99, 2, now(), 1000.00, 'карта');
