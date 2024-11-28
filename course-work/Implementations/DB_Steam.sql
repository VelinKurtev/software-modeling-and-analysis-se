CREATE DATABASE steam;
USE steam;

CREATE TABLE User_Account (
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

            IF @Tag_ID IS NULL
            BEGIN
                INSERT INTO Tag (Name) VALUES (@TagName);
                SET @Tag_ID = SCOPE_IDENTITY();
            END

            INSERT INTO GameTag (Game_ID, Tag_ID) VALUES (@Game_ID, @Tag_ID);
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

INSERT INTO User_Account (Username, Password_Hash, Email, Join_Date, Wallet_Balance)
VALUES 
('JohnDoe', 'hash1', 'john@example.com', GETDATE(), 50.00),
('JaneSmith', 'hash2', 'jane@example.com', GETDATE(), 100.00),
('AlexHunter', 'hash3', 'alex@example.com', GETDATE(), 75.00);

INSERT INTO Developer (Name, Country, Website)
VALUES 
('Epic Games', 'USA', 'https://www.epicgames.com'),
('Valve Corporation', 'USA', 'https://www.valvesoftware.com'),
('CD Projekt Red', 'Poland', 'https://www.cdprojektred.com');

INSERT INTO Tag (Name)
VALUES 
('Action'),
('Adventure'),
('Multiplayer'),
('Singleplayer'),
('RPG'),
('Shooter'),
('Open World');

INSERT INTO Game (Title, Genre, Release_Date, Developer_ID, Price)
VALUES 
('Fortnite', 'Action', '2017-07-21', 1, 0.00),
('Half-Life', 'Adventure', '1998-11-19', 2, 9.99),
('Cyberpunk 2077', 'RPG', '2020-12-10', 3, 59.99),
('The Witcher 3', 'RPG', '2015-05-18', 3, 39.99);

INSERT INTO GameTag (Game_ID, Tag_ID)
VALUES 
(1, 1), 
(1, 3),
(2, 2), 
(2, 6), 
(3, 5), 
(3, 7), 
(4, 5), 
(4, 7), 
(4, 4); 

INSERT INTO Review (User_ID, Game_ID, Rating, Comment, Review_Date)
VALUES 
(1, 1, 5, 'Amazing game!', GETDATE()),
(2, 2, 4, 'Classic masterpiece.', GETDATE()),
(3, 3, 3, 'Great visuals, but buggy.', GETDATE()),
(1, 4, 5, 'A masterpiece in RPGs.', GETDATE());

INSERT INTO Purchase (User_ID, Game_ID, Purchase_Date, Price_Paid, Payment_Method)
VALUES 
(2, 2, GETDATE(), 9.99, 'Credit Card'), 
(3, 3, GETDATE(), 59.99, 'PayPal'),
(1, 4, GETDATE(), 39.99, 'Debit Card');

INSERT INTO User_Account (Username, Password_Hash, Email, Join_Date, Wallet_Balance)
VALUES 
('GamerOne', 'hash4', 'gamer1@example.com', GETDATE(), 200.00),
('ProPlayer', 'hash5', 'proplayer@example.com', GETDATE(), 150.00),
('CasualGamer', 'hash6', 'casual@example.com', GETDATE(), 120.00),
('SpeedRunner', 'hash7', 'speedrunner@example.com', GETDATE(), 80.00),
('StrategyKing', 'hash8', 'strategy@example.com', GETDATE(), 60.00),
('MultiplayerAce', 'hash9', 'mpace@example.com', GETDATE(), 75.00),
('IndieFan', 'hash10', 'indiefan@example.com', GETDATE(), 90.00),
('RPGQueen', 'hash11', 'rpgqueen@example.com', GETDATE(), 200.00),
('AdventureLover', 'hash12', 'adventure@example.com', GETDATE(), 140.00),
('ShooterGod', 'hash13', 'shooter@example.com', GETDATE(), 100.00),
('StealthMaster', 'hash14', 'stealth@example.com', GETDATE(), 50.00),
('RetroGamer', 'hash15', 'retro@example.com', GETDATE(), 40.00),
('Collector', 'hash16', 'collector@example.com', GETDATE(), 300.00),
('BudgetGamer', 'hash17', 'budget@example.com', GETDATE(), 30.00),
('VRPlayer', 'hash18', 'vrplayer@example.com', GETDATE(), 220.00),
('MobaChamp', 'hash19', 'moba@example.com', GETDATE(), 160.00),
('PuzzleSolver', 'hash20', 'puzzle@example.com', GETDATE(), 70.00),
('SimFanatic', 'hash21', 'simfan@example.com', GETDATE(), 130.00),
('CraftingExpert', 'hash22', 'crafting@example.com', GETDATE(), 110.00),
('EsportsStar', 'hash23', 'esports@example.com', GETDATE(), 500.00);

INSERT INTO Developer (Name, Country, Website)
VALUES 
('Rockstar Games', 'USA', 'https://www.rockstargames.com'),
('Ubisoft', 'France', 'https://www.ubisoft.com'),
('Square Enix', 'Japan', 'https://www.square-enix.com'),
('Bethesda Game Studios', 'USA', 'https://bethesda.net'),
('Nintendo', 'Japan', 'https://www.nintendo.com'),
('SEGA', 'Japan', 'https://www.sega.com'),
('Blizzard Entertainment', 'USA', 'https://www.blizzard.com'),
('FromSoftware', 'Japan', 'https://www.fromsoftware.jp'),
('Capcom', 'Japan', 'https://www.capcom.com'),
('Bandai Namco', 'Japan', 'https://www.bandainamcoent.com'),
('Activision', 'USA', 'https://www.activision.com'),
('Electronic Arts', 'USA', 'https://www.ea.com'),
('Insomniac Games', 'USA', 'https://insomniac.games'),
('Remedy Entertainment', 'Finland', 'https://www.remedygames.com'),
('Kojima Productions', 'Japan', 'https://www.kojimaproductions.jp'),
('BioWare', 'Canada', 'https://www.bioware.com'),
('Respawn Entertainment', 'USA', 'https://www.respawn.com'),
('Treyarch', 'USA', 'https://www.treyarch.com'),
('Infinity Ward', 'USA', 'https://www.infinityward.com'),
('Obsidian Entertainment', 'USA', 'https://www.obsidian.net');

INSERT INTO Tag (Name)
VALUES 
('Survival'),
('Fantasy'),
('Horror'),
('Platformer'),
('Strategy'),
('Simulation'),
('Co-op'),
('Sandbox'),
('Battle Royale'),
('Arcade'),
('Stealth'),
('Racing'),
('Puzzle'),
('VR'),
('MOBA'),
('Crafting'),
('Esports'),
('Story-Rich'),
('Anime'),
('Historical');

INSERT INTO Game (Title, Genre, Release_Date, Developer_ID, Price)
VALUES 
('Grand Theft Auto V', 'Action', '2013-09-17', 5, 29.99),
('The Legend of Zelda: Breath of the Wild', 'Adventure', '2017-03-03', 9, 59.99),
('Dark Souls III', 'RPG', '2016-04-12', 8, 49.99),
('Overwatch 2', 'Shooter', '2022-10-04', 7, 39.99),
('Assassin’s Creed Valhalla', 'Action', '2020-11-10', 2, 59.99),
('The Sims 4', 'Simulation', '2014-09-02', 12, 39.99),
('FIFA 23', 'Sports', '2022-09-30', 12, 69.99),
('Elden Ring', 'RPG', '2022-02-25', 8, 59.99),
('Minecraft', 'Sandbox', '2011-11-18', 1, 26.95),
('Among Us', 'Multiplayer', '2018-06-15', 6, 4.99),
('Death Stranding', 'Adventure', '2019-11-08', 15, 59.99),
('Red Dead Redemption 2', 'Action', '2018-10-26', 5, 59.99),
('Fallout 4', 'RPG', '2015-11-10', 4, 29.99),
('Doom Eternal', 'Shooter', '2020-03-20', 4, 39.99),
('Star Wars Jedi: Fallen Order', 'Action', '2019-11-15', 17, 39.99),
('Control', 'Adventure', '2019-08-27', 14, 39.99),
('Mass Effect Legendary Edition', 'RPG', '2021-05-14', 16, 59.99),
('League of Legends', 'MOBA', '2009-10-27', 19, 0.00),
('Apex Legends', 'Shooter', '2019-02-04', 18, 0.00),
('Cyberpunk 2077', 'RPG', '2020-12-10', 3, 59.99);

INSERT INTO GameTag (Game_ID, Tag_ID)
VALUES 
(5, 1),
(5, 10),
(6, 2),
(6, 17),
(7, 16),
(8, 5),
(8, 7),
(9, 8),
(10, 3),
(10, 15),
(11, 4),
(12, 9),
(13, 11),
(13, 18),
(14, 12),
(15, 19),
(16, 14),
(17, 5),
(17, 18),
(18, 20);

INSERT INTO Review (User_ID, Game_ID, Rating, Comment, Review_Date)
VALUES 
(4, 5, 5, 'Open world perfection!', GETDATE()),
(5, 6, 4, 'Classic Sims fun.', GETDATE()),
(6, 7, 3, 'Same old FIFA.', GETDATE()),
(7, 8, 5, 'Incredible gameplay and lore.', GETDATE()),
(8, 9, 4, 'Still the best sandbox.', GETDATE()),
(9, 10, 5, 'Hilarious and fun.', GETDATE()),
(10, 11, 5, 'A walking simulator masterpiece.', GETDATE()),
(11, 12, 4, 'Immersive western experience.', GETDATE()),
(12, 13, 3, 'Decent but aged mechanics.', GETDATE()),
(13, 14, 5, 'Pure FPS adrenaline.', GETDATE()),
(14, 15, 5, 'Star Wars done right!', GETDATE()),
(15, 16, 5, 'Superb storytelling.', GETDATE()),
(16, 17, 4, 'Still a sci-fi RPG classic.', GETDATE()),
(17, 18, 5, 'MOBA gold standard.', GETDATE()),
(18, 19, 5, 'Battle royale evolved.', GETDATE()),
(19, 20, 3, 'Still too buggy.', GETDATE()),
(20, 1, 4, 'Great free-to-play game.', GETDATE()),
(3, 3, 2, 'Disappointing launch bugs.', GETDATE()),
(2, 6, 3, 'Good but expensive expansions.', GETDATE()),
(1, 4, 5, 'RPG perfection.', GETDATE());

INSERT INTO Purchase (User_ID, Game_ID, Purchase_Date, Price_Paid, Payment_Method)
VALUES 
(4, 5, GETDATE(), 29.99, 'Credit Card'),
(5, 6, GETDATE(), 39.99, 'PayPal'),
(6, 7, GETDATE(), 69.99, 'Debit Card'),
(7, 8, GETDATE(), 59.99, 'Credit Card'),
(8, 9, GETDATE(), 26.95, 'Gift Card'),
(9, 10, GETDATE(), 4.99, 'Credit Card'),
(10, 11, GETDATE(), 59.99, 'PayPal'),
(11, 12, GETDATE(), 59.99, 'Debit Card'),
(12, 13, GETDATE(), 29.99, 'Gift Card'),
(13, 14, GETDATE(), 39.99, 'Credit Card'),
(14, 15, GETDATE(), 39.99, 'PayPal'),
(15, 16, GETDATE(), 39.99, 'Credit Card'),
(16, 17, GETDATE(), 59.99, 'Credit Card'),
(17, 18, GETDATE(), 0.00, 'Free-to-play'),
(18, 19, GETDATE(), 0.00, 'Free-to-play'),
(19, 20, GETDATE(), 59.99, 'PayPal'),
(20, 1, GETDATE(), 50.00, 'Gift Card');
