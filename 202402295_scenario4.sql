-- Scenario 4: Campus Clinic Medicine Dispensing
-- Sample student numbers; replace as needed. Drops/recreates these tables.
DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;
CREATE TABLE medicines (medicine_id SERIAL PRIMARY KEY, medicine_name TEXT, available_qty INT CHECK(available_qty>=0));
CREATE TABLE dispensing_records (dispensing_id SERIAL PRIMARY KEY, medicine_id INT REFERENCES medicines, student_number TEXT NOT NULL, quantity INT CHECK(quantity>0), status TEXT DEFAULT 'DISPENSED');
INSERT INTO medicines(medicine_name,available_qty) VALUES ('Paracetamol',10),('Antiseptic Cream',4),('ORS',0);

-- IF / ELSIF / ELSE
DO $$ DECLARE n INT; BEGIN SELECT available_qty INTO n FROM medicines WHERE medicine_id=3;
 IF n=0 THEN RAISE NOTICE 'Medicine out of stock'; ELSIF n<=3 THEN RAISE NOTICE 'Low stock: %',n; ELSE RAISE NOTICE 'Sufficient stock: %',n; END IF; END $$;
-- WHILE and numeric FOR
DO $$ DECLARE i INT:=1; BEGIN WHILE i<=3 LOOP RAISE NOTICE 'Stock review day %',i; i:=i+1; END LOOP; END $$;
DO $$ DECLARE i INT; BEGIN FOR i IN 1..3 LOOP RAISE NOTICE 'Shelf inspection %',i; END LOOP; END $$;

CREATE OR REPLACE PROCEDURE dispense_medicine(mid INT, student TEXT, q INT) LANGUAGE plpgsql AS $$ BEGIN
 IF q IS NULL OR q<=0 THEN RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE='22023'; END IF;
 UPDATE medicines SET available_qty=available_qty-q WHERE medicine_id=mid AND available_qty>=q;
 IF NOT FOUND THEN RAISE EXCEPTION 'Medicine missing or insufficient stock' USING ERRCODE='P0001'; END IF;
 INSERT INTO dispensing_records(medicine_id,student_number,quantity) VALUES(mid,student,q);
END $$;
CALL dispense_medicine(1,'STU001',2);
CALL dispense_medicine(2,'STU002',3);
DO $$ BEGIN CALL dispense_medicine(3,'STU003',1); EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'Expected: %',SQLERRM; END $$;

CREATE OR REPLACE PROCEDURE reverse_dispensing(id INT) LANGUAGE plpgsql AS $$ DECLARE mid INT; q INT; BEGIN
 UPDATE dispensing_records SET status='REVERSED' WHERE dispensing_id=id AND status='DISPENSED' RETURNING medicine_id,quantity INTO mid,q;
 IF FOUND THEN UPDATE medicines SET available_qty=available_qty+q WHERE medicine_id=mid;
 ELSE RAISE NOTICE 'Already reversed or record not found; stock not restored'; END IF;
END $$;
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);
-- Explicit cursor: medicine stock at or below low-stock threshold (3)
DO $$ DECLARE c CURSOR FOR SELECT medicine_name,available_qty FROM medicines WHERE available_qty<=3; r RECORD; BEGIN
 OPEN c; LOOP FETCH c INTO r; EXIT WHEN NOT FOUND; RAISE NOTICE '%: % remaining',r.medicine_name,r.available_qty; END LOOP; CLOSE c;
END $$;
DO $$ BEGIN CALL dispense_medicine(1,'STU004',-1); EXCEPTION WHEN SQLSTATE '22023' THEN RAISE NOTICE 'Invalid quantity: %',SQLERRM; END $$;
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY dispensing_id;
