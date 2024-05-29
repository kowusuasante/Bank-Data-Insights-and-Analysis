--Table Creation

CREATE DATABASE COMMON_DATA_WAREHOUSE

USE COMMON_DATA_WAREHOUSE

CREATE TABLE GL
(
 GL_Account_ID BIGINT PRIMARY KEY NOT NULL,
 GL_Account NVARCHAR(10) NOT NULL,
 GL_Name NVARCHAR(50) NOT NULL,
 Group_GL_Account_ID BIGINT FOREIGN KEY REFERENCES Group_GL(Group_GL_Account_ID) NOT NULL,
 GL_Account_Type BIT NOT NULL,
 GL_Account_Name NVARCHAR(25) NOT NULL,
 )


CREATE TABLE Financial
(
 Agreement_ID BIGINT FOREIGN KEY REFERENCES Instrument(Agreement_ID) NOT NULL,
 GL_Account_ID BIGINT FOREIGN KEY REFERENCES GL(GL_Account_ID) NOT NULL,
 Source NVARCHAR(10) NULL,
 Customer_ID BIGINT FOREIGN KEY REFERENCES Customer(Customer_ID) NOT NULL,
 Amount DECIMAL(15,2) NOT NULL,
 )

BULK INSERT Financial
FROM 'G:\My Drive\Current\NCR\Working Files\Financial.csv'
WITH
(
    FORMAT='CSV',
    FIRSTROW=2, -- Skip the header row
    FIELDTERMINATOR = ',', -- Comma is the default field terminator
    ROWTERMINATOR = '\n'   -- Newline is the default row terminator
)

BULK INSERT GL
FROM 'G:\My Drive\Current\NCR\Working Files\GL.csv'
WITH
(
    FORMAT='CSV',
    FIRSTROW=2, -- Skip the header row
    FIELDTERMINATOR = ',', -- Comma is the default field terminator
    ROWTERMINATOR = '\n'   -- Newline is the default row terminator
)


ALTER TABLE Customer
ADD CONSTRAINT FK_Customer_Country FOREIGN KEY (Country) REFERENCES Country(Country);

ALTER TABLE Instrument
ADD CONSTRAINT FK_Instrument_Country FOREIGN KEY (Country) REFERENCES Country(Country);


SELECT * FROM Customer
SELECT * FROM Instrument
SELECT * FROM Financial
SELECT * FROM GL
SELECT * FROM Group_GL
SELECT * FROM Country


SELECT TOP 20* FROM Customer
SELECT TOP 20* FROM Financial
SELECT TOP 20* FROM Instrument
SELECT TOP 20* FROM Country
SELECT * FROM GL
SELECT * FROM Group_GL


USE COMMON_DATA_WAREHOUSE

--1. Read and profile the data. Explain your understanding about the data and provide insights.

SELECT COUNT(*) AS No_Of_Customers FROM Customer 
SELECT COUNT(*) AS Count_Of_Loan_Transactions FROM Financial
SELECT COUNT(*) AS GL_Information FROM GL
SELECT COUNT(*) AS Group_GL_Information FROM Group_GL
SELECT COUNT(*) AS Loan_Information FROM Instrument
SELECT COUNT(*) AS Countries FROM Country

SELECT TOP 20* FROM Customer
SELECT TOP 20* FROM Financial
SELECT TOP 20* FROM Instrument
SELECT TOP 20* FROM Country
SELECT * FROM GL
SELECT * FROM Group_GL


--NULL VALUES

SELECT * FROM Financial --no null values

SELECT * FROM GL -- no null values

SELECT * FROM Group_GL -- no null values

--Customer
SELECT * FROM Customer
WHERE  [NACE_Code_L1] IS NULL
	OR [NACE_Name_L1] IS NULL
	OR [NACE_Code] IS NULL
	OR [Bankrupcy_Flag] IS NULL
	OR [Rating_Score] IS NULL
	OR [Country] IS NULL
	OR [Customer_Responsible_Unit] IS NULL
	OR [Sector_Code] IS NULL
	OR [Sector_Name] IS NULL

--Instrument
SELECT * FROM Instrument
WHERE [Performing_Non_Performing] IS NULL
   OR [Effective_Date] IS NULL
   OR [Closing_Date] IS NULL
   OR [Maturity_Date] IS NULL
   OR [Registration_Date] IS NULL
   OR [Country] IS NULL
   OR [Basel_FT_ID] IS NULL
   OR [Last_Repricing_Date] IS NULL
   OR [Agreement_Purpose] IS NULL
   OR [Amortization_Method] IS NULL

--Overview of Customers by Geography

--No of Customers per Continent:
SELECT C.Continent, Count(*) as Count_Of_Customers
FROM Customer CS
LEFT JOIN Country C on C.Country = CS.Country
GROUP BY C.Continent
ORDER BY Count_Of_Customers DESC

--No of Customers per Country
SELECT C.Country, C.Country_Name, Count(*) as Count_Of_Customers
FROM Customer CS
LEFT JOIN Country C on C.Country = CS.Country
GROUP BY C.Country, C.Country_Name
ORDER BY Count_Of_Customers DESC

--Customer Classification

--Business Classification
SELECT NACE_Name_L1, COUNT(*) AS Count_Of_Business_Classification
FROM Customer
GROUP BY NACE_Name_L1
ORDER BY Count_Of_Business_Classification DESC

--Sectors
SELECT Sector_Name, COUNT(*) AS Count_Of_Sector_Name
FROM Customer
GROUP BY Sector_Name
ORDER BY Count_Of_Sector_Name DESC

--Customer Health and Performance

--Bankruptcy
SELECT Bankrupcy_Flag, COUNT(*) AS Count_Of_Bankruptcy
FROM Customer
GROUP BY Bankrupcy_Flag
ORDER BY Count_Of_Bankruptcy DESC


--Performing and Non-Performing Loans 
SELECT Performing_Non_Performing, COUNT(DISTINCT CS.Customer_ID) AS No_Of_Customers
FROM Customer CS
LEFT JOIN Financial F on F.Customer_ID = CS.Customer_ID
LEFT JOIN Instrument I ON I.Agreement_ID = F.Agreement_ID
GROUP BY Performing_Non_Performing
ORDER BY No_Of_Customers desc

--Instrument Analysis

--Amortization Methods
SELECT Amortization_Method, COUNT(*) AS Amortization_Count
FROM Instrument
GROUP BY Amortization_Method
ORDER BY Amortization_Count DESC

--Agreement Purpose
SELECT Agreement_Purpose, COUNT(*) AS Agreement_Count
FROM Instrument
GROUP BY Agreement_Purpose
ORDER BY Agreement_Count DESC

--Performing and Non-Performing Loans [Instruments]
SELECT Performing_Non_Performing, COUNT(*) AS Count_
FROM Instrument
GROUP BY Performing_Non_Performing
ORDER BY Count_ DESC

--Organizational Insight

--Customer Responsible Unit
SELECT DISTINCT Customer_Responsible_Unit
FROM Customer

--2. Explain the assets and off balances for each customer sector category.

SELECT COUNT(GL.GL_Account_ID) AS Total_Count, GL.GL_Account_Name, C.Sector_Name,SUM(F.Amount) AS Total_Amount
FROM GL
LEFT JOIN Financial F ON GL.GL_Account_ID = F.GL_Account_ID
LEFT JOIN Customer C ON F.Customer_ID = C.Customer_ID
GROUP BY GL.GL_Account_Name, C.Sector_Name
ORDER BY C.Sector_Name DESC;

SELECT COUNT(GL.GL_Account_ID) AS Total_Count, GL.GL_Account_Name, 'All Sectors' AS Sector_Name, SUM(F.Amount) AS Total_Amount
FROM GL
LEFT JOIN Financial F ON GL.GL_Account_ID = F.GL_Account_ID
LEFT JOIN Customer C ON F.Customer_ID = C.Customer_ID
WHERE GL.GL_Account_Name IN ('Assets', 'Off-balance-sheet items')
GROUP BY GL.GL_Account_Name
ORDER BY Total_Amount DESC;


--3. Explain the total amount for each sector category before and after adjustment. Hint: Adjustments have “ADJ” text in Source attribute.

SELECT Sector_Name,
    SUM(CASE WHEN Source NOT LIKE '%ADJ%' THEN Amount ELSE 0 END) AS Before_Adjustment,
	SUM(CASE WHEN Source LIKE '%ADJ%' THEN Amount ELSE 0 END) AS After_Adjustment
FROM Customer CS
LEFT JOIN Financial F ON F.Customer_ID = CS.Customer_ID
GROUP BY Sector_Name
ORDER BY Sector_Name;

--4. Explain the amounts aggregated on countries. Show which country has maximum assets per NACE code and sector category.

WITH AggregatedAssets AS (
SELECT CT.Country_Name, C.Country, C.NACE_Code, C.Sector_Name, SUM(F.Amount) AS Total_Amount
FROM Customer C
LEFT JOIN Financial F ON C.Customer_ID = F.Customer_ID
LEFT JOIN GL G ON F.GL_Account_ID = G.GL_Account_ID
LEFT JOIN Country CT ON C.Country = CT.Country
WHERE G.GL_Account_Name = 'Assets'
GROUP BY CT.Country_Name, C.Country, C.NACE_Code, C.Sector_Name
),
RankedAssets AS (
SELECT Country_Name, Country, NACE_Code, Sector_Name, Total_Amount,ROW_NUMBER() OVER (PARTITION BY NACE_Code, Sector_Name ORDER BY Total_Amount ASC) AS rn
FROM AggregatedAssets
)
SELECT Country_Name, Country, NACE_Code, Sector_Name, Total_Amount
FROM RankedAssets
WHERE rn = 1
ORDER BY NACE_Code, Sector_Name;

--5.What are the total assets for missing Customer Responsible Unit? Can you find any trend from customer or instrument perspective?

WITH MissingCRUAssets AS (
SELECT C.Customer_ID, C.Country, CT.Country_Name, NACE_Code,C.NACE_Name_L1,C.Sector_Name, SUM(F.Amount) AS Total_Amount
FROM Customer C
LEFT JOIN Financial F ON F.Customer_ID = C.Customer_ID
LEFT JOIN GL G ON G.GL_Account_ID = F.GL_Account_ID
LEFT JOIN Country CT on CT.Country = C.Country
WHERE C.Customer_Responsible_Unit IS NULL AND G.GL_Account_Name = 'Assets'
GROUP BY C.Customer_ID, C.Country, CT.Country_Name, NACE_Code,C.NACE_Name_L1,C.Sector_Name
)
SELECT Country_Name, Country, NACE_Code,NACE_Name_L1, Sector_Name, SUM(Total_Amount) AS Total_Assets, COUNT(Customer_ID) AS Num_Customers
FROM MissingCRUAssets
GROUP BY Country_Name, Country, NACE_Code,NACE_Name_L1, Sector_Name
ORDER BY Total_Assets ASC;


/* 
6. Considering the rating/scores as below priority order:
a.	“6+”, “6-“, “6” - Highest rating
b.	“0+”, “0-“, “0” – Lowest rating (Defaulted)
c.	“A+”, “A-“, “A” – Highest score
d.	“0+”, “0-“, “0” – Lowest score (Defaulted)
e.	U – Unassigned

Explain identified anomalies with performance of instruments.*/

WITH RatingClassification AS (
SELECT CS.Customer_ID, F.Agreement_ID, I.Performing_Non_Performing, CS.Rating_Score,
     CASE
        WHEN CS.Rating_Score IN ('PC6+', 'PC6-', 'PC6') THEN 'Highest Rating'
        WHEN CS.Rating_Score IN ('PC0+', 'PC0-', 'PC0') THEN 'Lowest Rating (Defaulted)'
        WHEN CS.Rating_Score IN ('PPA+', 'PPA-', 'PPA') THEN 'Highest Score'
        WHEN CS.Rating_Score IN ('PP0+', 'PP0-', 'PP0') THEN 'Lowest Score (Defaulted)'
        WHEN CS.Rating_Score IN ('PCU', 'PPU') THEN 'Unassigned'
        END AS Rating_Classification

FROM Customer CS
LEFT JOIN Financial F ON F.Customer_ID = CS.Customer_ID
LEFT JOIN Instrument I ON I.Agreement_ID = F.Agreement_ID
)

SELECT Rating_Classification, I.Performing_Non_Performing,
    COUNT(DISTINCT RC.Customer_ID) AS No_Of_Customers,
    COUNT(DISTINCT I.Agreement_ID) AS No_Of_Instruments
FROM RatingClassification RC
LEFT JOIN Instrument I ON RC.Agreement_ID = I.Agreement_ID
GROUP BY Rating_Classification, I.Performing_Non_Performing
ORDER BY Rating_Classification, No_Of_Customers DESC;

--7.	Explain any other observation about the data. 






