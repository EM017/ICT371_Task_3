-- Scenario 2: Computer Laboratory Reservations
-- Drops/recreates these tables.
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;
CREATE TABLE lab_sessions (session_id SERIAL PRIMARY KEY, session_name TEXT, total_workstations INT, available_workstations INT CHECK(available_workstations>=0));
CREATE TABLE reservations (reservation_id SERIAL PRIMARY KEY, session_id INT REFERENCES lab_sessions, lecturer TEXT NOT NULL, workstation_count INT CHECK(workstation_count>0), status TEXT DEFAULT 'RESERVED');
INSERT INTO lab_sessions(session_name,total_workstations,available_workstations) VALUES ('Morning',20,20),('Afternoon',10,10),('Evening',5,5);

-- IF / ELSIF / ELSE
DO $$ DECLARE a INT; t INT; BEGIN SELECT available_workstations,total_workstations INTO a,t FROM lab_sessions WHERE session_id=1;
 IF a=0 THEN RAISE NOTICE 'Session full'; ELSIF a<=t/4 THEN RAISE NOTICE 'Nearly full'; ELSE RAISE NOTICE 'Enough workstations'; END IF; END $$;
-- WHILE and numeric FOR
DO $$ DECLARE i INT:=1; BEGIN WHILE i<=3 LOOP RAISE NOTICE 'Preparation reminder %',i; i:=i+1; END LOOP; END $$;
DO $$ DECLARE i INT; BEGIN FOR i IN 1..3 LOOP RAISE NOTICE 'Workstation check %',i; END LOOP; END $$;

CREATE OR REPLACE PROCEDURE reserve_workstations(sid INT, who TEXT, q INT) LANGUAGE plpgsql AS $$ BEGIN
 IF q IS NULL OR q<=0 THEN RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE='22023'; END IF;
 UPDATE lab_sessions SET available_workstations=available_workstations-q WHERE session_id=sid AND available_workstations>=q;
 IF NOT FOUND THEN RAISE EXCEPTION 'Session missing or not enough workstations' USING ERRCODE='P0001'; END IF;
 INSERT INTO reservations(session_id,lecturer,workstation_count) VALUES(sid,who,q);
END $$;
CALL reserve_workstations(1,'Dr Banda',6);
CALL reserve_workstations(2,'Ms Phiri',8);
DO $$ BEGIN CALL reserve_workstations(3,'Mr Tembo',6); EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'Expected: %',SQLERRM; END $$;

CREATE OR REPLACE PROCEDURE cancel_reservation(id INT) LANGUAGE plpgsql AS $$ DECLARE sid INT; q INT; BEGIN
 UPDATE reservations SET status='CANCELLED' WHERE reservation_id=id AND status='RESERVED' RETURNING session_id,workstation_count INTO sid,q;
 IF FOUND THEN UPDATE lab_sessions SET available_workstations=available_workstations+q WHERE session_id=sid;
 ELSE RAISE NOTICE 'Already cancelled or reservation not found; capacity unchanged'; END IF;
END $$;
CALL cancel_reservation(1);
CALL cancel_reservation(1);
-- Explicit cursor: sessions with few workstations left
DO $$ DECLARE c CURSOR FOR SELECT session_name,available_workstations FROM lab_sessions WHERE available_workstations<=3; r RECORD; BEGIN
 OPEN c; LOOP FETCH c INTO r; EXIT WHEN NOT FOUND; RAISE NOTICE '%: % workstations left',r.session_name,r.available_workstations; END LOOP; CLOSE c;
END $$;
DO $$ BEGIN CALL reserve_workstations(1,'Dr Banda',0); EXCEPTION WHEN SQLSTATE '22023' THEN RAISE NOTICE 'Invalid quantity: %',SQLERRM; END $$;
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;
