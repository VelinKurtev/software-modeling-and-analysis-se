--CREATE DATABASE steam;
--USE steam;

CREATE TABLE User_Account ( --Cannot use User
	User_ID INT IDENTITY(1,1) PRIMARY KEY,  
    Username NVARCHAR(100) NOT NULL,       
    Password_Hash NVARCHAR(255) NOT NULL,  
    Email NVARCHAR(100) NOT NULL,          
    Join_Date DATETIME NOT NULL,            
    Wallet_Balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00
);

CREATE TABLE Developer (
    Developer_ID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(255) NOT NULL,               
    Country NVARCHAR(100),                     
    Website NVARCHAR(255)                      
);

CREATE TABLE Tag (
    Tag_ID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,         
);

CREATE TABLE Game (
    Game_ID INT IDENTITY(1,1) PRIMARY KEY, 
    Title NVARCHAR(255) NOT NULL,          
    Genre NVARCHAR(100),                   
    Release_Date DATE,                     
    Developer_ID INT NOT NULL,             
    Price DECIMAL(10, 2) NOT NULL CHECK (Price >= 0), 
    CONSTRAINT FK_Developer_Game FOREIGN KEY (Developer_ID) REFERENCES Developer(Developer_ID)
);

CREATE TABLE Review (
    Review_ID INT IDENTITY(1,1) PRIMARY KEY,  
    User_ID INT NOT NULL,                    
    Game_ID INT NOT NULL,                     
    Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),  
    Comment NVARCHAR(MAX),                
    Review_Date DATETIME NOT NULL,            
    CONSTRAINT FK_User_Review FOREIGN KEY (User_ID) REFERENCES User_Account(User_ID), 
    CONSTRAINT FK_Game_Review FOREIGN KEY (Game_ID) REFERENCES Game(Game_ID)
);

CREATE TABLE GameTag (
    Game_ID INT NOT NULL,                  
    Tag_ID INT NOT NULL,                  
    PRIMARY KEY (Game_ID, Tag_ID),         
    CONSTRAINT FK_Game_GameTag FOREIGN KEY (Game_ID) REFERENCES Game(Game_ID),
    CONSTRAINT FK_Tag_GameTag FOREIGN KEY (Tag_ID) REFERENCES Tag(Tag_ID)      
);

CREATE TABLE Purchase (
    Purchase_ID INT IDENTITY(1,1) PRIMARY KEY, 
    User_ID INT NOT NULL,                      
    Game_ID INT NOT NULL,                      
    Purchase_Date DATETIME NOT NULL,           
    Price_Paid DECIMAL(10, 2) NOT NULL CHECK (Price_Paid >= 0), 
    Payment_Method NVARCHAR(50) NOT NULL,      
    CONSTRAINT FK_User_Purchase FOREIGN KEY (User_ID) REFERENCES User_Account(User_ID),
    CONSTRAINT FK_Game_Purchase FOREIGN KEY (Game_ID) REFERENCES Game(Game_ID) 
);

GO
CREATE PROCEDURE AddNewGame
    @Title NVARCHAR(255),
    @Genre NVARCHAR(100),
    @Release_Date DATE,
    @Developer_ID INT,
    @Price DECIMAL(10, 2),
    @TagNames NVARCHAR(MAX)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Game (Title, Genre, Release_Date, Developer_ID, Price)
        VALUES (@Title, @Genre, @Release_Date, @Developer_ID, @Price);

        DECLARE @Game_ID INT = SCOPE_IDENTITY();

        DECLARE @TagName NVARCHAR(100);
        DECLARE @Tag_ID INT;

        WHILE LEN(@TagNames) > 0
        BEGIN
            SET @TagName = LEFT(@TagNames, CHARINDEX(',', @TagNames + ',') - 1);
            SET @TagNames = STUFF(@TagNames, 1, LEN(@TagName) + 1, '');

            SELECT @Tag_ID = Tag_ID FROM Tag WHERE Name = @TagName;
            
            IF @Tag_ID IS NOT NULL
            BEGIN
                INSERT INTO GameTag (Game_ID, Tag_ID) VALUES (@Game_ID, @Tag_ID);
            END
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

GO
-- AVG Game Rating
CREATE FUNCTION GetAverageRating (@Game_ID INT)
RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @AvgRating DECIMAL(3, 2);
    SELECT @AvgRating = AVG(CAST(Rating AS DECIMAL(3, 2)))
    FROM Review
    WHERE Game_ID = @Game_ID;

    RETURN @AvgRating;
END;
GO

GO
CREATE TRIGGER DeductWalletBalance
ON Purchase
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE User_Account
    SET Wallet_Balance = Wallet_Balance - i.Price_Paid
    FROM User_Account ua
    INNER JOIN Inserted i ON ua.User_ID = i.User_ID;

    IF EXISTS (SELECT 1 FROM User_Account WHERE Wallet_Balance < 0)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50000, 'Insufficient wallet balance.', 1;
    END
END;
GO

-- Populate Database
-- Insert sample users
INSERT INTO User_Account (Username, Password_Hash, Email, Join_Date, Wallet_Balance)
VALUES 
('JohnDoe', 'hash1', 'john@example.com', GETDATE(), 50.00),
('JaneSmith', 'hash2', 'jane@example.com', GETDATE(), 100.00);

-- Insert sample developers
INSERT INTO Developer (Name, Country, Website)
VALUES 
('Epic Games', 'USA', 'https://www.epicgames.com'),
('Valve Corporation', 'USA', 'https://www.valvesoftware.com');

-- Insert sample tags
INSERT INTO Tag (Name)
VALUES 
('Action'),
('Adventure'),
('Multiplayer');

-- Insert sample games
INSERT INTO Game (Title, Genre, Release_Date, Developer_ID, Price)
VALUES 
('Fortnite', 'Action', '2017-07-21', 1, 0.00),
('Half-Life', 'Adventure', '1998-11-19', 2, 9.99);

-- Insert sample reviews
INSERT INTO Review (User_ID, Game_ID, Rating, Comment, Review_Date)
VALUES 
(1, 1, 5, 'Amazing game!', GETDATE()),
(2, 2, 4, 'Classic masterpiece.', GETDATE());

-- Insert sample purchases
INSERT INTO Purchase (User_ID, Game_ID, Purchase_Date, Price_Paid, Payment_Method)
VALUES 
(2, 2, GETDATE(), 9.99, 'Credit Card');