SELECT
    SPLIT_PART(a.Name, ' ', 1) AS FirstName,
    SPLIT_PART(a.Name, ' ', 2) AS LastName,
    CASE
        WHEN a.AuthorGender = 'MALE' THEN 'MUŠKI'
        WHEN a.AuthorGender = 'FEMALE' THEN 'ŽENSKI'
        WHEN a.AuthorGender = 'UNKNOWN' THEN 'NEPOZNATO'
        ELSE 'OSTALO'
    END AS Gender,
    c.Name AS CountryName,
    c.AverageSalary
FROM
    Authors a
JOIN
    Countries c ON a.CountryID = c.CountryID;


SELECT
    b.Title AS BookTitle,
    b.DateOfPublishment AS PublicationDate,
    STRING_AGG(
        CONCAT(SPLIT_PART(a.Name, ' ', 2), '.', LEFT(SPLIT_PART(a.Name, ' ', 1), 1)),
        '; ' ORDER BY au.Authorship DESC
    ) AS MainAuthors
FROM
    Books b
JOIN
    Authorships au ON b.BookID = au.BookID
JOIN
    Authors a ON au.AuthorID = a.AuthorID
WHERE
    b.BookType = 'SCIENTIFIC' AND au.Authorship = 'MAIN'
GROUP BY
    b.BookID, b.Title, b.DateOfPublishment;




SELECT
    l.LibraryID,
    l.Name AS LibraryName,
    COUNT(c.CopyID) AS NumberOfCopies
FROM
    Libraries l
JOIN
    Copies c ON l.LibraryID = c.LibraryID
GROUP BY
    l.LibraryID, l.Name
ORDER BY
    NumberOfCopies DESC
LIMIT 3;


SELECT
    b.BookID,
    b.Title AS BookTitle,
    COUNT(DISTINCT bo.UserID) AS NumberOfReaders
FROM
    Books b
LEFT JOIN
    Copies c ON b.BookID = c.BookID
LEFT JOIN
    Borrowings bo ON c.CopyID = bo.CopyID
WHERE
    bo.BorrowingID IS NOT NULL
GROUP BY
    b.BookID, b.Title
ORDER BY
    NumberOfReaders DESC;


SELECT Name AS UserName 
FROM Users u
INNER JOIN Borrowings b on b.UserID = u.UserID
WHERE returnDate IS NULL;


SELECT a.Name AS AuthorName, b.DateOfPublishment
FROM Authors a
INNER JOIN Authorships au ON a.AuthorID = au.AuthorID
INNER JOIN Books b ON b.BookID = au.BookID
WHERE EXTRACT(YEAR FROM b.DateOfPublishment) > 2019 AND EXTRACT(YEAR FROM b.DateOfPublishment) <= 2022;

WITH UniqueAuthors AS (
    SELECT DISTINCT
        a.AuthorID,
        a.Name,
        a.DateOfBirth,
        a.DateOfDeath,
        a.AuthorGender,
        a.CountryID
    FROM
        Authors a
)

SELECT
    c.Name AS CountryName,
    COUNT(DISTINCT b.BookID) AS NumberOfArtisticBooks,
    COUNT(DISTINCT ua.AuthorID) AS NumberOfLivingAuthors
FROM
    Books b
JOIN
    Authorships au ON b.BookID = au.BookID
JOIN
    UniqueAuthors ua ON au.AuthorID = ua.AuthorID
JOIN
    Countries c ON ua.CountryID = c.CountryID
WHERE
    b.BookType = 'ARTISTIC' AND ua.DateOfDeath IS NULL
GROUP BY
    c.CountryID, c.Name
ORDER BY
    NumberOfLivingAuthors DESC;




SELECT
    a.AuthorID,
    a.Name AS AuthorName,
    b.BookID,
    b.Title AS BookTitle,
    b.BookType AS Genre,
    COUNT(bo.BorrowingID) AS NumberOfBorrowings
FROM
    Authors a
JOIN
    Authorships au ON a.AuthorID = au.AuthorID
JOIN
    Books b ON au.BookID = b.BookID
LEFT JOIN
    Borrowings bo ON b.BookID = bo.CopyID
GROUP BY
    a.AuthorID, a.Name, b.BookID, b.Title, b.BookType
ORDER BY
    a.AuthorID, b.BookID;


SELECT
    a.AuthorID,
    a.Name AS AuthorName,
    MIN(b.DateOfPublishment) AS FirstPublicationDate,
    MIN(b.Title) AS FirstPublishedBook
FROM
    Authors a
JOIN
    Authorships au ON a.AuthorID = au.AuthorID
JOIN
    Books b ON au.BookID = b.BookID
GROUP BY
    a.AuthorID, a.Name
ORDER BY
    a.AuthorID;


WITH RankedBooks AS (
    SELECT
        b.BookID,
        b.Title,
        b.DateOfPublishment,
        a.CountryID,
        ROW_NUMBER() OVER (PARTITION BY a.CountryID ORDER BY b.DateOfPublishment) AS BookRank
    FROM
        Books b
    JOIN
        Authorships au ON b.BookID = au.BookID
    JOIN
        Authors a ON au.AuthorID = a.AuthorID
)
SELECT
    r.CountryID,
    c.Name AS CountryName,
    MAX(CASE WHEN r.BookRank = 2 THEN r.Title END) AS SecondPublishedBook
FROM
    RankedBooks r
JOIN
    Countries c ON r.CountryID = c.CountryID
GROUP BY
    r.CountryID, c.Name
ORDER BY
    r.CountryID;


SELECT
    b.BookID,
    b.Title,
    COUNT(*) AS ActiveBorrowings
FROM
    Books b
JOIN
    Copies c ON b.BookID = c.BookID
JOIN
    Borrowings bo ON c.CopyID = bo.CopyID
WHERE
    bo.ReturnDate IS NULL
GROUP BY
    b.BookID, b.Title
HAVING
    COUNT(*) >= 10
ORDER BY
    ActiveBorrowings DESC;


    WITH BorrowingsPerCopy AS (
    SELECT
        c.BookID,
        a.CountryID,
        COUNT(bo.BorrowingID) AS NumBorrowings,
        COUNT(DISTINCT bo.CopyID) AS NumCopies
    FROM
        Copies c
    JOIN
        Borrowings bo ON c.CopyID = bo.CopyID
    JOIN
        Authorships au ON c.BookID = au.BookID
    JOIN
        Authors a ON au.AuthorID = a.AuthorID
    GROUP BY
        c.BookID, a.CountryID
)
SELECT
    bpc.CountryID,
    c.Name AS CountryName,
    AVG(CAST(bpc.NumBorrowings AS DECIMAL) / bpc.NumCopies) AS AvgBorrowingsPerCopy
FROM
    BorrowingsPerCopy bpc
JOIN
    Countries c ON bpc.CountryID = c.CountryID
GROUP BY
    bpc.CountryID, c.Name
ORDER BY
    AvgBorrowingsPerCopy DESC;


WITH AuthorCounts AS (
    SELECT
        a.AuthorID,
        a.Name,
        a.DateOfBirth,
        b.BookType AS Gender,  
        COUNT(DISTINCT au.BookID) AS NumBooksPublished
    FROM
        Authors a
    JOIN
        Authorships au ON a.AuthorID = au.AuthorID
    JOIN
        Books b ON au.BookID = b.BookID
    GROUP BY
        a.AuthorID, a.Name, a.DateOfBirth, b.BookType
    HAVING
        COUNT(DISTINCT au.BookID) > 5
)
SELECT
    FLOOR(EXTRACT(DECADE FROM ac.DateOfBirth)::INTEGER / 10) * 10 AS BirthDecade,
    ac.Gender AS BookType,  
    COUNT(DISTINCT ac.AuthorID) AS NumAuthors
FROM
    AuthorCounts ac
GROUP BY
    BirthDecade, ac.Gender
HAVING
    COUNT(DISTINCT ac.AuthorID) >= 10
ORDER BY
    BirthDecade, NumAuthors DESC;


WITH AuthorEarnings AS (
    SELECT
        a.AuthorID,
        a.Name,
        SUM(SQRT(c.NumberOfCopies) / au.AuthorshipCount) AS Earnings
    FROM
        Authors a
    JOIN (
        SELECT
            au.AuthorID,
            COUNT(DISTINCT au.BookID) AS AuthorshipCount
        FROM
            Authorships au
        GROUP BY
            au.AuthorID
    ) au ON a.AuthorID = au.AuthorID
    JOIN
        Authorships aship ON a.AuthorID = aship.AuthorID
    JOIN
        Copies c ON aship.BookID = c.BookID
    GROUP BY
        a.AuthorID, a.Name
)
SELECT
    ae.AuthorID,
    ae.Name,
    ae.Earnings
FROM
    AuthorEarnings ae
ORDER BY
    ae.Earnings DESC
LIMIT 10;

