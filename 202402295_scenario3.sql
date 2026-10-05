-- Scenario 3: Student Hostel Room Allocation
-- Sample student numbers; replace as needed. Drops/recreates these tables.
DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;
CREATE TABLE hostel_rooms (room_id SERIAL PRIMARY KEY, room_name TEXT, available_beds INT CHECK(available_beds>=0));
CREATE TABLE allocations (allocation_id SERIAL PRIMARY KEY, student_number TEXT NOT NULL, room_id INT REFERENCES hostel_rooms, status TEXT DEFAULT 'ACTIVE');
INSERT INTO hostel_rooms(room_name,available_beds) VALUES ('A1',2),('A2',1),('B1',0);

-- IF / ELSIF / ELSE
DO $$ DECLARE n INT; BEGIN SELECT available_beds INTO n FROM hostel_rooms WHERE room_id=2;
 IF n=0 THEN RAISE NOTICE 'Room is full'; ELSIF n=1 THEN RAISE NOTICE 'One bed left'; ELSE RAISE NOTICE 'Several beds left'; END IF; END $$;
-- WHILE and numeric FOR
DO $$ DECLARE i INT:=1; BEGIN WHILE i<=3 LOOP RAISE NOTICE 'Inspection day %',i; i:=i+1; END LOOP; END $$;
DO $$ DECLARE i INT; BEGIN FOR i IN 1..3 LOOP RAISE NOTICE 'Room check %',i; END LOOP; END $$;

CREATE OR REPLACE PROCEDURE allocate_room(student TEXT, rid INT) LANGUAGE plpgsql AS $$ BEGIN
 IF student IS NULL OR trim(student)='' THEN RAISE EXCEPTION 'Student number cannot be blank' USING ERRCODE='22023'; END IF;
 UPDATE hostel_rooms SET available_beds=available_beds-1 WHERE room_id=rid AND available_beds>0;
 IF NOT FOUND THEN RAISE EXCEPTION 'Room missing or full' USING ERRCODE='P0001'; END IF;
 INSERT INTO allocations(student_number,room_id) VALUES(student,rid);
END $$;
CALL allocate_room('STU001',1);
CALL allocate_room('STU002',2);
DO $$ BEGIN CALL allocate_room('STU003',3); EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'Expected: %',SQLERRM; END $$;

CREATE OR REPLACE PROCEDURE check_out(id INT) LANGUAGE plpgsql AS $$ DECLARE rid INT; BEGIN
 UPDATE allocations SET status='CHECKED_OUT' WHERE allocation_id=id AND status='ACTIVE' RETURNING room_id INTO rid;
 IF FOUND THEN UPDATE hostel_rooms SET available_beds=available_beds+1 WHERE room_id=rid;
 ELSE RAISE NOTICE 'Already checked out or allocation not found; no bed released'; END IF;
END $$;
CALL check_out(1);
CALL check_out(1);
-- Explicit cursor: full rooms or rooms with one bed left
DO $$ DECLARE c CURSOR FOR SELECT room_name,available_beds FROM hostel_rooms WHERE available_beds<=1; r RECORD; BEGIN
 OPEN c; LOOP FETCH c INTO r; EXIT WHEN NOT FOUND; RAISE NOTICE '%: % bed(s)',r.room_name,r.available_beds; END LOOP; CLOSE c;
END $$;
DO $$ BEGIN CALL allocate_room('   ',1); EXCEPTION WHEN SQLSTATE '22023' THEN RAISE NOTICE 'Invalid student number: %',SQLERRM; END $$;
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
