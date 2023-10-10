--1)Can you provide the SQL showing the number of customers that do not match the standard 10 digit phone number format (excluding hyphens)?

SELECT COUNT(*) as num_customers_with_invalid_phone -- Count the number of customers whose phone numbers do not match the standard 10 digit phone number format (excluding hyphens)
FROM Person.PersonPhone pp -- Join the PersonPhone table
JOIN Sales.Customer c ON pp.BusinessEntityID = c.PersonID -- Join the Customer table on the PersonID field
WHERE REPLACE(REPLACE(PhoneNumber, '-', ''), ' ', '') -- Remove any hyphens or spaces from the phone number using the REPLACE function
NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' -- Filter for phone numbers that do not match the standard 10 digit format (excluding hyphens) using the NOT LIKE operator and a regular expression-like pattern


--2)Can you supply the number of customers with a Last Name starting with  “BE”?

	SELECT 
    COUNT(*) as num_customers_with_last_name_be -- Count the number of matching records and assign an alias to the result
FROM 
    Person.Person p -- Select from the Person.Person table and assign it an alias 'p'
    JOIN Sales.Customer c ON p.BusinessEntityID = c.PersonID -- Join the Sales.Customer table on the BusinessEntityID and PersonID fields
    JOIN Person.PersonPhone pp ON pp.BusinessEntityID = p.BusinessEntityID -- Join the Person.PersonPhone table on the BusinessEntityID field
WHERE 
    p.LastName LIKE 'BE%'; -- Filter the results for customers whose Last Name starts with "BE"


--3)Can you create a list of the top 3 sales by “Total Due” for each customer grouped orders grouped by product and product category?

 -- Common Table Expression (CTE) to calculate total sales by customer and product category
	WITH SalesByCustomer AS (
  SELECT c.CustomerID, p.Name AS ProductName, pc.Name AS ProductCategoryName, 
         SUM(od.LineTotal) AS TotalSales
  FROM Sales.SalesOrderHeader soh
  JOIN Sales.SalesOrderDetail od ON soh.SalesOrderID = od.SalesOrderID
  JOIN Production.Product p ON od.ProductID = p.ProductID
  JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
  JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
  JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
  GROUP BY c.CustomerID, p.Name, pc.Name
),
-- Common Table Expression (CTE) to rank customers by total sales for each product category
RankSalesByCustomer AS (
  SELECT CustomerID, ProductName, ProductCategoryName, TotalSales, 
         ROW_NUMBER() OVER(PARTITION BY CustomerID, ProductCategoryName ORDER BY TotalSales DESC) AS Rank
  FROM SalesByCustomer
)
-- Select top 3 customers for each product category based on their total sales 
SELECT CustomerID, ProductName, ProductCategoryName, TotalSales
FROM RankSalesByCustomer
WHERE Rank <= 3;



--4)	Can you create SQL that compares the Salesorder detail line item totals vs Total Salesorder total due

SELECT 
  sod.SalesOrderID, -- select the SalesOrderID from SalesOrderDetail
  SUM(sod.LineTotal) as LineTotal, -- Sum of LineTotal from SalesOrderDetail
  so.TotalDue -- TotalDue from SalesOrderHeader
FROM 
  Sales.SalesOrderDetail sod -- Join SalesOrderDetail table
  JOIN Sales.SalesOrderHeader so ON sod.SalesOrderID = so.SalesOrderID -- Join SalesOrderHeader table
GROUP BY 
  sod.SalesOrderID, so.TotalDue -- group by SalesOrderID and TotalDue
HAVING 
  SUM(sod.LineTotal) <> so.TotalDue; -- Filter the groups where sum of LineTotal is not equal to TotalDue


--5)	Can you list out all order details and list out the last order date based on the customerID?  This will be based on the last order compared to the current order made.

SELECT
    c.CustomerID, -- select the customer ID
    o.SalesOrderID, -- select the sales order ID
    od.ProductID, -- select the product ID
    od.OrderQty, -- select the order quantity
    od.UnitPrice, -- select the unit price
    od.LineTotal, -- select the line total
    o.TotalDue, -- select the total due
    od.LineTotal - (od.OrderQty * od.UnitPrice) AS Discount, -- calculate the discount
    od.LineTotal * 100.0 / o.TotalDue AS Percentage, -- calculate the percentage of line total
    od.ModifiedDate, -- select the modified date of the order detail
    MAX(o.ModifiedDate) OVER (PARTITION BY c.CustomerID) AS LastOrderDate -- select the latest modified date for each customer
FROM 
    Sales.SalesOrderHeader o -- join the sales order header table
    JOIN Sales.SalesOrderDetail od ON o.SalesOrderID = od.SalesOrderID -- join the sales order detail table
    JOIN Sales.Customer c ON o.CustomerID = c.CustomerID -- join the customer table
ORDER BY 
    c.CustomerID, o.SalesOrderID; -- sort the results by customer ID and sales order ID



--6) Can you provide data for all of the prior points in temporary tables?

 --Question 1
	SELECT pp.BusinessEntityID, pp.PhoneNumber as num_customers_with_invalid_phone -- Count the number of customers whose phone numbers do not match
INTO #InvalidPhones
FROM Person.PersonPhone pp -- Join the PersonPhone table
JOIN Sales.Customer c ON pp.BusinessEntityID = c.PersonID -- Join the Customer table on the PersonID field
WHERE REPLACE(REPLACE(PhoneNumber, '-', ''), ' ', '') -- Remove any hyphens or spaces from the phone number using the REPLACE function
NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'




--Question2
SELECT p.BusinessEntityID, p.LastName
INTO #LastNameBE
FROM Person.Person p
JOIN Sales.Customer c ON p.BusinessEntityID = c.PersonID
JOIN Person.PersonPhone pp ON pp.BusinessEntityID = p.BusinessEntityID
WHERE p.LastName LIKE 'BE%'


--Question3
CREATE TABLE #Top3Sales (
    CustomerID INT,
    ProductName NVARCHAR(50),
    ProductCategoryName NVARCHAR(50),
    TotalSales MONEY
);
WITH SalesByCustomer AS (
    SELECT c.CustomerID, p.Name AS ProductName, pc.Name AS ProductCategoryName, 
           SUM(od.LineTotal) AS TotalSales
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail od ON soh.SalesOrderID = od.SalesOrderID
    JOIN Production.Product p ON od.ProductID = p.ProductID
    JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
    JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
    GROUP BY c.CustomerID, p.Name, pc.Name
),
RankSalesByCustomer AS (
    SELECT CustomerID, ProductName, ProductCategoryName, TotalSales, 
           ROW_NUMBER() OVER(PARTITION BY CustomerID, ProductCategoryName ORDER BY TotalSales DESC) AS Rank
    FROM SalesByCustomer
)
INSERT INTO #Top3Sales
SELECT CustomerID, ProductName, ProductCategoryName, TotalSales
FROM RankSalesByCustomer
WHERE Rank <= 3;


--Question4
SELECT od.SalesOrderID, SUM(od.LineTotal) AS LineItemTotal, so.TotalDue
INTO #SalesOrderComparison
FROM Sales.SalesOrderDetail od
JOIN Sales.SalesOrderHeader so ON od.SalesOrderID = so.SalesOrderID
GROUP BY od.SalesOrderID, so.TotalDue
HAVING SUM(od.LineTotal) <> so.TotalDue


--Question5

CREATE TABLE #OrderDetails
(
    CustomerID INT,
    SalesOrderID INT,
    ProductID INT,
    OrderQty INT,
    UnitPrice MONEY,
    LineTotal MONEY,
    TotalDue MONEY,
    Discount MONEY,
    Percentage FLOAT,
    ModifiedDate DATETIME,
    LastOrderDate DATETIME
)

INSERT INTO #OrderDetails 
    od.UnitPrice,
    od.LineTotal,
    o.TotalDue,
    od.LineTotal - (od.OrderQty * od.UnitPrice) AS Discount,
    od.LineTotal * 100.0 / o.TotalDue AS Percentage,
    od.ModifiedDate,
    MAX(o.ModifiedDate) OVER (PARTITION BY c.CustomerID) AS LastOrderDate
FROM 
    Sales.SalesOrderHeader o
    JOIN Sales.SalesOrderDetail od ON o.SalesOrderID = od.SalesOrderID
    JOIN Sales.Customer c ON o.CustomerID = c.CustomerID
ORDER BY 
    c.CustomerID, o.SalesOrderID;

