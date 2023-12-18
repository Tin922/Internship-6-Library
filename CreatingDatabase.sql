CREATE TABLE Countries (
    CountryID SERIAL PRIMARY KEY,
    Name VARCHAR(50),
    Population INT NOT NULL,
    AverageSalary DOUBLE PRECISION  NOT NULL
);

create table Libraries (
	LibraryID SERIAL PRIMARY KEY,
	Name VARCHAR(80) NOT NULL,
	OpeningTime VARCHAR(50),
    ClosingTime VARCHAR(50)
);

create table Books(
	BookID SERIAL PRIMARY KEY,
	Title VARCHAR(200) NOT NULL,	
	DateOfPublishment DATE NOT NULL, 
	BookType VARCHAR(50) NOT NULL 
);
CREATE TABLE Copies(
	CopyID SERIAL PRIMARY KEY,
	Code VARCHAR(50) NOT NULL,
	BookID INT REFERENCES Books(BookID),
	LibraryID INT REFERENCES Libraries(LibraryID)
	
);

CREATE TABLE Authors(
	AuthorID SERIAL PRIMARY KEY,
	Name VARCHAR(50),
	DateOfBirth DATE NOT NULL,
	DateOfDeath DATE,
	AuthorGender VARCHAR(50),
    FieldOfStudy VARCHAR(50) NOT NULL,  
	CountryID INT REFERENCES Countries (CountryID)
);
CREATE TABLE Authorships (   
	AuthorID INT,
    BookID INT,
    Authorship VARCHAR(20) NOT NULL,
    PRIMARY KEY (AuthorID, BookID),
    FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID),
    FOREIGN KEY (BookID) REFERENCES Books(BookID)
);


CREATE TABLE Librarian(
	LibrarianID SERIAL PRIMARY KEY,
	Name VARCHAR(50)
);

CREATE TABLE Users(
	UserID SERIAL PRIMARY KEY,
	Name VARCHAR(50) NOT NULL	
);


CREATE TABLE Borrowings(
	BorrowingID SERIAL PRIMARY KEY,
	BorrowDate DATE NOT NULL,
    DueDate DATE NOT NULL,
	ReturnDate DATE,
	ExtensionDays INT DEFAULT 0,
	LateFee DECIMAL(5, 2),
    CopyID INT REFERENCES Copies(CopyID),
    UserID INT REFERENCES Users(UserID)
	
);



ALTER TABLE Authors
ADD CONSTRAINT CK_Gender
CHECK (AuthorGender IN ('MALE', 'FEMALE', 'UNKNOWN', 'OTHER'));

ALTER TABLE Borrowings
ADD CONSTRAINT CK_ReturnDate
CHECK (ReturnDate > BorrowDate);

ALTER TABLE Books
ADD CONSTRAINT CK_BookType
CHECK (BookType IN ('TEXTBOOK', 'ARTISTIC', 'SCIENTIFIC', 'BIOGRAPHY', 'PROFESSIONAL'));

ALTER TABLE Authorships
ADD CONSTRAINT CK_AuthorType
CHECK (Authorship IN ('MAIN', 'CONTRIBUTING'));



CREATE OR REPLACE FUNCTION SetDueDateFunction()
RETURNS TRIGGER AS $$
BEGIN
    NEW.DueDate := NEW.BorrowDate + INTERVAL '20 days';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER SetDueDate
BEFORE INSERT ON Borrowings
FOR EACH ROW
EXECUTE FUNCTION SetDueDateFunction();




CREATE OR REPLACE FUNCTION CalculateReturnFeeAndSave(
    in_borrowing_id INT
) RETURNS DECIMAL(5, 2) AS $$
DECLARE
    return_fee DECIMAL(5, 2) := 0.50; 
    is_lektira BOOLEAN;
    is_summer BOOLEAN;
    days_late INT;
BEGIN
    
    SELECT
        CASE WHEN b.BookType = 'TEXTBOOK' THEN TRUE ELSE FALSE END
    INTO is_lektira
    FROM
        Borrowings bor
        JOIN Copies c ON bor.CopyID = c.CopyID
        JOIN Books b ON c.BookID = b.BookID
    WHERE
        bor.BorrowingID = in_borrowing_id;

    
    SELECT
        CASE WHEN EXTRACT(MONTH FROM bor.ReturnDate) BETWEEN 6 AND 9 THEN TRUE ELSE FALSE END
    INTO is_summer
    FROM
        Borrowings bor
    WHERE
        bor.BorrowingID = in_borrowing_id;    

SELECT 	(SELECT ReturnDate FROM Borrowings WHERE BorrowingID = in_borrowing_id) - (SELECT DueDate FROM Borrowings WHERE BorrowingID = in_borrowing_id) INTO days_late;



   
    IF is_lektira THEN
        
        IF is_summer THEN
            
            return_fee := 0.50 * days_late;  
        ELSE
           
            return_fee := 0.50 * days_late;  
        END IF;
    ELSE
        
        IF is_summer THEN
            
            IF EXTRACT(ISODOW FROM (SELECT ReturnDate FROM Borrowings WHERE BorrowingID = in_borrowing_id)) IN (6, 7) THEN
            
                return_fee := 0.20 * days_late;  
            ELSE
                
                return_fee := 0.30 * days_late;  
            END IF;
        ELSE
          
            IF EXTRACT(ISODOW FROM (SELECT ReturnDate FROM Borrowings WHERE BorrowingID = in_borrowing_id)) IN (6, 7) THEN
               
                return_fee := 0.20 * days_late;  
            ELSE
                
                return_fee := 0.40 * days_late;  
            END IF;
        END IF;
    END IF;

   
    UPDATE Borrowings
    SET LateFee = return_fee
    WHERE BorrowingID = in_borrowing_id;

    RETURN return_fee;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_late_fee_after_insert()
RETURNS TRIGGER AS $$
BEGIN
    NEW.LateFee := CalculateReturnFeeAndSave(NEW.BorrowingID);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_insert_update_late_fee_trigger
AFTER INSERT ON Borrowings
FOR EACH ROW
EXECUTE FUNCTION update_late_fee_after_insert();




CREATE OR REPLACE PROCEDURE LendBook(IN copy_id INT, IN user_id INT) AS $$
DECLARE
    due_date DATE;
    is_copy_available BOOLEAN;
    num_loaned_books INT;
    new_borrowing_id INT;
BEGIN
  
    IF NOT EXISTS (SELECT 1 FROM Users WHERE UserID = user_id) THEN
        RAISE EXCEPTION 'The specified user does not exist.';
    END IF;

    
    SELECT COUNT(*) INTO num_loaned_books
    FROM Borrowings
    WHERE UserID = user_id AND ReturnDate IS NULL;

    
    IF num_loaned_books >= 3 THEN
        RAISE EXCEPTION 'User has already borrowed 3 books and cannot borrow more.';
    END IF;

    
    IF NOT EXISTS (SELECT 1 FROM Copies WHERE CopyID = copy_id) THEN
        RAISE EXCEPTION 'The specified copy does not exist.';
    END IF;


    SELECT COUNT(*) = 0 INTO is_copy_available
    FROM Borrowings
    WHERE CopyID = copy_id AND ReturnDate IS NULL;

    IF NOT is_copy_available THEN
        RAISE EXCEPTION 'The book copy is already borrowed and cannot be lent again.';
    END IF;


    SELECT COALESCE(MAX(BorrowingID), 0) + 1 INTO new_borrowing_id
    FROM Borrowings;


    SELECT CURRENT_DATE + INTERVAL '20 days' INTO due_date;


    INSERT INTO Borrowings (BorrowingID, BorrowDate, DueDate, CopyID, UserID)
    VALUES (new_borrowing_id, CURRENT_DATE, due_date, copy_id, user_id);

    
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE PROCEDURE ExtendReturnDate(
    IN borrowing_id INT,
    IN extension_days_to_add INT
) AS $$
DECLARE
    current_date DATE;
    original_due_date DATE;
    extended_due_date DATE;
    extension_days INT;
    max_extension_days INT := 40;
BEGIN
   
    SELECT CURRENT_DATE INTO current_date;

   
    SELECT DueDate, ExtensionDays
    INTO original_due_date, extension_days
    FROM Borrowings
    WHERE BorrowingID = borrowing_id;

 
    IF original_due_date IS NULL THEN
        RAISE EXCEPTION 'Borrowing with ID % does not exist.', borrowing_id;
    END IF;

 
    IF extension_days + extension_days_to_add > max_extension_days THEN
        RAISE EXCEPTION 'Extension limit (% days) reached for BorrowingID %.', max_extension_days, borrowing_id;
    END IF;

    
   extended_due_date := LEAST(original_due_date + interval '60 days', original_due_date + interval '1 day' * extension_days_to_add);


   UPDATE Borrowings
    SET ReturnDate = NULL,
        DueDate = extended_due_date,
        ExtensionDays = extension_days + extension_days_to_add
    WHERE BorrowingID = borrowing_id;
END;
$$ LANGUAGE plpgsql;


