-- Scenario 1: University Library Book Loans
-- Uses sample student numbers; replace them as needed. Drops/recreates these tables.
DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;
CREATE TABLE books (book_id SERIAL PRIMARY KEY, title TEXT, available_copies INT CHECK (available_copies >= 0));
CREATE TABLE book_loans (loan_id SERIAL PRIMARY KEY, student_number TEXT NOT NULL, book_id INT REFERENCES books, quantity INT CHECK (quantity > 0), status TEXT DEFAULT 'ACTIVE');
INSERT INTO books (title, available_copies) VALUES ('PostgreSQL Basics',5),('Database Systems',2),('SQL Guide',0);

-- IF / ELSIF / ELSE
DO $$ DECLARE n INT; BEGIN
 SELECT available_copies INTO n FROM books WHERE book_id=3;
 IF n=0 THEN RAISE NOTICE 'Unavailable'; ELSIF n<=2 THEN RAISE NOTICE 'Low stock: % copies',n; ELSE RAISE NOTICE 'Sufficient stock: % copies',n; END IF;
END $$;
-- WHILE and numeric FOR
DO $$ DECLARE i INT:=1; BEGIN WHILE i<=3 LOOP RAISE NOTICE 'Overdue reminder %',i; i:=i+1; END LOOP; END $$;
DO $$ DECLARE i INT; BEGIN FOR i IN 1..3 LOOP RAISE NOTICE 'Shelf %',i; END LOOP; END $$;

CREATE OR REPLACE PROCEDURE borrow_book(b INT, s TEXT, q INT) LANGUAGE plpgsql AS $$ BEGIN
 IF q IS NULL OR q<=0 THEN RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE='22023'; END IF;
 UPDATE books SET available_copies=available_copies-q WHERE book_id=b AND available_copies>=q;
 IF NOT FOUND THEN RAISE EXCEPTION 'Book missing or not enough copies' USING ERRCODE='P0001'; END IF;
 INSERT INTO book_loans(student_number,book_id,quantity) VALUES(s,b,q);
END $$;
CALL borrow_book(1,'STU001',2);
CALL borrow_book(2,'STU002',1);
DO $$ BEGIN CALL borrow_book(3,'STU003',1); EXCEPTION WHEN SQLSTATE 'P0001' THEN RAISE NOTICE 'Expected: %',SQLERRM; END $$;

CREATE OR REPLACE PROCEDURE return_book(id INT) LANGUAGE plpgsql AS $$ DECLARE b INT; q INT; BEGIN
 UPDATE book_loans SET status='RETURNED' WHERE loan_id=id AND status='ACTIVE' RETURNING book_id,quantity INTO b,q;
 IF FOUND THEN UPDATE books SET available_copies=available_copies+q WHERE book_id=b;
 ELSE RAISE NOTICE 'Already returned or loan not found; no copies restored'; END IF;
END $$;
CALL return_book(1);
CALL return_book(1);
-- Explicit cursor: low-stock books
DO $$ DECLARE c CURSOR FOR SELECT title,available_copies FROM books WHERE available_copies<=2; r RECORD; BEGIN
 OPEN c; LOOP FETCH c INTO r; EXIT WHEN NOT FOUND; RAISE NOTICE '%: % copies',r.title,r.available_copies; END LOOP; CLOSE c;
END $$;
DO $$ BEGIN CALL borrow_book(1,'STU004',0); EXCEPTION WHEN SQLSTATE '22023' THEN RAISE NOTICE 'Invalid quantity: %',SQLERRM; END $$;
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
