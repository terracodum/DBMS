-- ============================
-- Лабораторная работа №3
-- Создание и связывание таблиц базы данных в среде PostgreSQL
-- Выполнять после подключения к базе данных sales (\c sales)
-- ============================

-----------------------------------------
-- Создание таблицы categories
-----------------------------------------
CREATE TABLE categories (
    cat_ID integer NOT NULL,
    cat_name text NOT NULL,
    cat_overcat integer,
    CONSTRAINT categories_PK PRIMARY KEY (cat_ID)
);

-----------------------------------------
-- Создание таблицы manufacturers
-----------------------------------------
CREATE TABLE manufacturers (
    man_ID integer NOT NULL,
    man_name text NOT NULL,
    man_address text NOT NULL,
    CONSTRAINT manufacturers_PK PRIMARY KEY (man_ID)
);

-----------------------------------------
-- Создание таблицы products
-----------------------------------------
CREATE TABLE products (
    prod_ID integer NOT NULL,
    prod_name text NOT NULL,
    prod_price numeric(8,2) NOT NULL,
    prod_rest integer NOT NULL,
    prod_cat_ID integer NOT NULL,
    prod_man_ID integer NOT NULL,
    CONSTRAINT products_PK PRIMARY KEY (prod_ID)
);

-----------------------------------------
-- Создание таблицы customers
-----------------------------------------
CREATE TABLE customers (
    cust_ID integer NOT NULL,
    cust_name text NOT NULL,
    cust_address text NOT NULL,
    cust_discount integer NOT NULL,
    CONSTRAINT customers_PK PRIMARY KEY (cust_ID)
);

-----------------------------------------
-- Создание таблицы employees
-----------------------------------------
CREATE TABLE employees (
    emp_ID integer NOT NULL,
    emp_name text NOT NULL,
    emp_position text NOT NULL,
    CONSTRAINT employees_PK PRIMARY KEY (emp_ID)
);

-----------------------------------------
-- Создание таблицы orders
-----------------------------------------
CREATE TABLE orders (
    ord_ID integer NOT NULL,
    ord_cust_ID integer NOT NULL,
    ord_emp_ID integer NOT NULL,
    ord_date date NOT NULL,
    CONSTRAINT orders_PK PRIMARY KEY (ord_ID)
);

-----------------------------------------
-- Создание таблицы items
-----------------------------------------
CREATE TABLE items (
    item_ID integer NOT NULL,
    item_ord_ID integer NOT NULL,
    item_prod_ID integer NOT NULL,
    item_prod_count integer NOT NULL,
    CONSTRAINT items_PK PRIMARY KEY (item_ID)
);

-----------------------------------------
-- Определение внешних ключей
-----------------------------------------
ALTER TABLE categories
ADD CONSTRAINT categories_FK FOREIGN KEY (cat_overcat)
REFERENCES categories (cat_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE products
ADD CONSTRAINT products_FK1 FOREIGN KEY (prod_cat_ID)
REFERENCES categories (cat_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE products
ADD CONSTRAINT products_FK2 FOREIGN KEY (prod_man_ID)
REFERENCES manufacturers (man_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE orders
ADD CONSTRAINT orders_FK1 FOREIGN KEY (ord_cust_ID)
REFERENCES customers (cust_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE orders
ADD CONSTRAINT orders_FK2 FOREIGN KEY (ord_emp_ID)
REFERENCES employees (emp_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE items
ADD CONSTRAINT items_FK1 FOREIGN KEY (item_ord_ID)
REFERENCES orders (ord_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE items
ADD CONSTRAINT items_FK2 FOREIGN KEY (item_prod_ID)
REFERENCES products (prod_ID)
ON DELETE CASCADE
ON UPDATE CASCADE;
