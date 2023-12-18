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