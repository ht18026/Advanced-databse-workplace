-- copy tables from MONEQUIP schema to current schema
CREATE TABLE ADDRESS AS SELECT * FROM MONEQUIP.ADDRESS;
CREATE TABLE CATEGORY AS SELECT * FROM MONEQUIP.CATEGORY;
CREATE TABLE CUSTOMER AS SELECT * FROM MONEQUIP.CUSTOMER;
CREATE TABLE CUSTOMER_TYPE AS SELECT * FROM MONEQUIP.CUSTOMER_TYPE;
CREATE TABLE EQUIPMENT AS SELECT * FROM MONEQUIP.EQUIPMENT;
CREATE TABLE HIRE AS SELECT * FROM MONEQUIP.HIRE;
CREATE TABLE SALES AS SELECT * FROM MONEQUIP.SALES;
CREATE TABLE STAFF AS SELECT * FROM MONEQUIP.STAFF;
commit;
--check tables copied
SELECT * FROM ADDRESS;
SELECT * FROM CATEGORY;
SELECT * FROM CUSTOMER;
SELECT * FROM CUSTOMER_TYPE;
SELECT * FROM EQUIPMENT;    
SELECT * FROM HIRE;
SELECT * FROM SALES;
SELECT * FROM STAFF;

--data cleaning for CUSTOMER_TYPE table
DELETE FROM CUSTOMER_TYPE WHERE DESCRIPTION = 'business';
COMMIT;
--data cleaning for category table   
SELECT *
FROM CATEGORY
WHERE CATEGORY_DESCRIPTION = 'null';

SELECT COUNT(*) AS ref_cnt
FROM equipment
WHERE category_id = 15;

UPDATE category
SET category_description = 'Unknown'
WHERE category_id = 15;
COMMIT;

--data cleaning for customer table   
SELECT customer_id, COUNT(*)
FROM CUSTOMER
GROUP BY CUSTOMER_ID
HAVING COUNT(*) > 1;
SELECT * FROM CUSTOMER where customer_id = 52;

DROP table customer;
CREATE TABLE CUSTOMER AS SELECT distinct * FROM MONEQUIP.CUSTOMER;
commit;

SELECT * from customer where customer_id is NULL;
SELECT * from customer where customer_type_id not in (SELECT CUSTOMER_TYPE.CUSTOMER_TYPE_ID from CUSTOMER_TYPE);
SELECT * from customer where address_id not in (SELECT address_id from ADDRESS);
SELECT distinct gender from customer;

DELETE from customer where customer_id is NULL;

--address:no thing
SELECT * from address where address_id is NULL;
SELECT * from address where postcode is NULL;
SELECT distinct suburb from address;
SELECT address_id, COUNT(*)
FROM ADDRESS
GROUP BY address_id
HAVING COUNT(*) > 1;

--equipment:no thing
SELECT * from equipment;
SELECT * from equipment where equipment_id is NULL;
SELECT * from EQUIPMENT where category_id not in (SELECT category_id from CATEGORY);
SELECT EQUIPMENT.EQUIPMENT_ID, COUNT(*)
FROM EQUIPMENT
GROUP BY EQUIPMENT_ID
HAVING COUNT(*) > 1;
SELECT distinct equipment.EQUIPMENT_name from equipment;

--hire
DROP table hire;
SELECT * from hire where hire_id is NULL;
SELECT * from hire;
SELECT * from hire where customer_id not in (SELECT customer_id from customer);
DELETE from hire where customer_id not in (SELECT customer_id from customer);

SELECT * from hire where hire.STAFF_ID not in (SELECT staff_id from STAFF);
DELETE from hire where hire.STAFF_ID not in (SELECT staff_id from STAFF);

SELECT * from hire where  (End_Date - Start_Date) * hire.UNIT_HIRE_PRICE * hire.QUANTITY <> hire.TOTAL_HIRE_PRICE;



update hire set TOTAL_HIRE_PRICE =  (End_Date - Start_Date) * UNIT_HIRE_PRICE * QUANTITY where
(End_Date - Start_Date) * hire.UNIT_HIRE_PRICE * hire.QUANTITY <> hire.TOTAL_HIRE_PRICE;
commit;

select * FROM hire where end_date < start_date;
delete from hire where end_date < start_date;
commit;

SELECT * from hire where end_date = start_date;
update hire set TOTAL_HIRE_PRICE = floor(UNIT_HIRE_PRICE * QUANTITY *0.5) where
 end_date = start_date;

commit;
--sales
SELECT * from sales;
SELECT * from sales where sales_id is NULL;
SELECT sales_ID, COUNT(*)
FROM SALES
GROUP BY sales_ID
HAVING COUNT(*) > 1;
select * from sales where customer_id not in (SELECT customer_id from customer);
select * from sales where STAFF_ID not in (SELECT staff_id from STAFF);

SELECT * from sales where UNIT_sales_PRICE * QUANTITY <> TOTAL_sales_PRICE;

SELECT * from sales where QUANTITY < 0;

update sales set QUANTITY = -QUANTITY where QUANTITY < 0;

UPDATE sales set TOTAL_sales_PRICE = UNIT_sales_PRICE * QUANTITY where
 sales.UNIT_sales_PRICE * sales.QUANTITY <> sales.TOTAL_sales_PRICE;

select * FROM sales where sales_id = 151;

select * from sales WHERE sales_id = 152;
DELETE from sales WHERE sales_id = 152;


commit;