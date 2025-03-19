USE Test_data;
-- QUESTION 1:
/* 
Write an SQL query to calculate the total sales of furniture products, grouped by each quarter of the year, 
and order the results chronologically. */
SELECT
    YEAR(O.ORDER_DATE) AS Year,
    DATEPART(QUARTER, O.ORDER_DATE) AS Quarter,
    ROUND(SUM(O.SALES),2) AS TotalSales
FROM
    ORDERS O
JOIN
    PRODUCT P ON O.PRODUCT_ID = P.ID  -- Join to get the product category
WHERE
    P.NAME = 'Furniture'  -- Filter for furniture products
GROUP BY
    YEAR(O.ORDER_DATE),
    DATEPART(QUARTER, O.ORDER_DATE)
ORDER BY
    Year ASC,
    Quarter ASC;

-- QUESTION 2:
/* 
Analyze the impact of different discount levels on sales performance across product categories, 
specifically looking at the number of orders and total profit generated for each discount classification.

Discount level condition:
No Discount = 0
0 < Low Discount <= 0.2
0.2 < Medium Discount <= 0.5
High Discount > 0.5 
*/
SELECT
    P.CATEGORY,
    CASE 
        WHEN O.Discount = 0 THEN 'No Discount'
        WHEN O.Discount > 0 AND O.Discount <= 0.2 THEN 'Low Discount'
        WHEN O.Discount > 0.2 AND O.Discount <= 0.5 THEN 'Medium Discount'
        WHEN O.Discount > 0.5 THEN 'High Discount'
    END AS Discount_Class,
    COUNT(O.ORDER_ID) AS Numbe_of_Orders,
    ROUND(SUM(O.PROFIT),2) AS Total_Profit
FROM
    ORDERS O
JOIN
    PRODUCT P ON O.PRODUCT_ID = P.ID
GROUP BY
    P.CATEGORY,
    CASE 
        WHEN O.Discount = 0 THEN 'No Discount'
        WHEN O.Discount > 0 AND O.Discount <= 0.2 THEN 'Low Discount'
        WHEN O.Discount > 0.2 AND O.Discount <= 0.5 THEN 'Medium Discount'
        WHEN O.Discount > 0.5 THEN 'High Discount'
    END
ORDER BY
    P.CATEGORY,
    Discount_Class;

-- QUESTION 3:
/* 
Determine the top-performing product categories within each customer segment based on sales and profit, 
focusing specifically on those categories that rank within the top two for profitability. 
*/
WITH RankedCategories AS (
    SELECT 
        C.SEGMENT,            -- Customer segment
        P.CATEGORY,            -- Product category
        SUM(O.SALES) AS TotalSales,  -- Total sales for the category
		RANK() OVER (PARTITION BY C.Segment ORDER BY SUM(O.SALES) DESC) AS Sales_Rank,
        SUM(O.PROFIT) AS TotalProfit, -- Total profit for the category
        RANK() OVER (PARTITION BY C.SEGMENT ORDER BY SUM(O.PROFIT) DESC) AS Profit_Rank  -- Rank categories within each segment based on profit
    FROM 
        ORDERS O
    INNER JOIN 
        PRODUCT P ON O.PRODUCT_ID = P.ID   -- Join with the Product table
    INNER JOIN 
        CUSTOMER C ON O.CUSTOMER_ID = C.ID -- Join with the Customer table
    GROUP BY 
        C.SEGMENT, P.CATEGORY    -- Group by customer segment and product category
)

-- Select only the top 2 categories per customer segment based on profitability
SELECT 
    SEGMENT,
    CATEGORY,
    Sales_Rank,
    Profit_Rank
FROM 
    RankedCategories
WHERE 
    Profit_Rank <= 2  -- Top 2 categories by profit within each customer segment
ORDER BY 
    SEGMENT, Profit_Rank;

-- QUESTION 4
/*
Create a report that displays each employee's performance across different product categories, showing not only the 
total profit per category but also what percentage of their total profit each category represents, with the result 
ordered by the percentage in descending order for each employee.
*/

SELECT 
    E.ID_EMPLOYEE,
    P.CATEGORY,
    ROUND(SUM(O.PROFIT), 2) AS Rounded_Total_Profit,
	ROUND((SUM(O.PROFIT) / SUM(SUM(O.PROFIT)) OVER (PARTITION BY E.ID_EMPLOYEE)) * 100, 2) AS Profit_Percentage
   
FROM 
    ORDERS O

INNER JOIN 
        EMPLOYEES E ON O.ID_EMPLOYEE = E.ID_EMPLOYEE
INNER JOIN 
        PRODUCT P ON O.PRODUCT_ID = p.ID
GROUP BY 
        E.ID_EMPLOYEE, P.CATEGORY
ORDER BY 
    ID_EMPLOYEE, Profit_Percentage DESC;  

-- QUESTION 5:
/*
Develop a user-defined function in SQL Server to calculate the profitability ratio for each product category 
an employee has sold, and then apply this function to generate a report that sorts each employee's product categories
by their profitability ratio.
*/

DROP FUNCTION dbo.fn_CalculateProfitability;
GO
CREATE FUNCTION dbo.fn_CalculateProfitability
(
    @EmployeeID INT,
    @Category VARCHAR(100)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        -- Calculate the total profit and total sales for the employee and category
        SUM(o.Profit) AS TotalProfit,
        SUM(o.SALES) AS TotalSales,
        -- Calculate profitability ratio (total profit / total sales)
        CASE
            WHEN SUM(o.SALES) = 0 THEN 0
            ELSE SUM(o.Profit) / SUM(o.SALES)
        END AS ProfitabilityRatio
    FROM 
        Orders o
    INNER JOIN 
        Product p ON o.PRODUCT_ID = p.ID
    WHERE 
        o.ID_EMPLOYEE = @EmployeeID
    AND 
        p.Category = @Category
    GROUP BY 
        o.ID_EMPLOYEE, p.Category
);
GO
SELECT 
    e.ID_EMPLOYEE,
    p.Category,
    ROUND(pf.TotalSales,2) AS Total_Sales,
	ROUND(pf.TotalProfit,2) AS Total_Profit,
    ROUND(pf.ProfitabilityRatio,2) AS Profitability_Ratio
FROM 
    Employees e
INNER JOIN 
    Orders o ON e.ID_EMPLOYEE = o.ID_EMPLOYEE
INNER JOIN 
    Product p ON o.PRODUCT_ID = p.ID
-- Use the UDF to get TotalProfit, TotalSales, and ProfitabilityRatio for each employee and category
CROSS APPLY 
    dbo.fn_CalculateProfitability(e.ID_EMPLOYEE, p.Category) AS pf
GROUP BY 
    e.ID_EMPLOYEE, p.Category, pf.TotalProfit, pf.TotalSales, pf.ProfitabilityRatio
ORDER BY 
    E.ID_EMPLOYEE, pf.ProfitabilityRatio DESC;  -- Sort by profitability ratio in descending order


-- QUESTION 6:
/* 
Write a stored procedure to calculate the total sales and profit for a specific EMPLOYEE_ID over a specified date range. 
The procedure should accept EMPLOYEE_ID, StartDate, and EndDate as parameters.
*/
GO
CREATE PROCEDURE dbo.CalculateEmployeeSalesAndProfit
    @EMPLOYEE_ID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    -- Declare variables to hold the results
    DECLARE @TotalSales DECIMAL(18, 2);
    DECLARE @TotalProfit DECIMAL(18, 2);

    -- Calculate Total Sales and Profit for the employee within the specified date range
    SELECT 
        @TotalSales = SUM(O.SALES),  
        @TotalProfit = SUM(O.PROFIT)       
    FROM 
        ORDERS O
    WHERE 
        O.ID_EMPLOYEE = @EMPLOYEE_ID
        AND O.ORDER_DATE BETWEEN @StartDate AND @EndDate;  -- Filter by the date range

    -- Return the results
    SELECT 
        @EMPLOYEE_ID AS EmployeeID,
        @TotalSales AS TotalSales,
        @TotalProfit AS TotalProfit;
END;
GO

EXEC dbo.CalculateEmployeeSalesAndProfit
    @EMPLOYEE_ID = 3,
    @StartDate = '2016-12-01',
    @EndDate = '2016-12-31';


-- QUESTION 7:
/*
Write a query using dynamic SQL query to calculate the total profit for the last six quarters in the datasets, 
pivoted by quarter of the year, for each state.
*/
DECLARE @StartDate DATE,
		@EndDate DATE,
		@DynamicSQL NVARCHAR(MAX),
        @QuartersList NVARCHAR(MAX);

-- Calculate the first day of the current quarter
SELECT @EndDate = MAX(O.ORDER_DATE) 
FROM Orders O;
SET @StartDate = DATEADD(QUARTER, DATEDIFF(QUARTER, '19000101', @EndDate) - 6, '19000101');

-- Create a list of quarter identifiers for the last 6 quarters
SET @QuartersList = '';
DECLARE @i INT = 0;

WHILE @i < 6
BEGIN
    -- Generate the quarter string in the format 'YYYY-Qx'
    SET @QuartersList = @QuartersList + 
        QUOTENAME(CONVERT(VARCHAR(4), DATEPART(YEAR, DATEADD(QUARTER, -@i, @EndDate))) + '-Q' + 
        CONVERT(VARCHAR(1), DATEPART(QUARTER, DATEADD(QUARTER, -@i, @EndDate)))) + ',';  
    SET @i = @i + 1;
END;

-- Remove the trailing comma
SET @QuartersList = LEFT(@QuartersList, LEN(@QuartersList) - 1);

-- Debugging Step: Print the @QuartersList to see how it looks
PRINT 'Quarters List: ' + @QuartersList;

-- Create the dynamic SQL query
SET @DynamicSQL = '
SELECT 
    State, 
    ' + @QuartersList + '
FROM 
    (SELECT 
         C.State,
		 CONCAT(YEAR(O.ORDER_DATE), ''-Q'', DATEPART(QUARTER, O.ORDER_DATE)) AS QUARTER_YEAR,
         O.Profit AS TotalProfit

     FROM 
         Orders o
	JOIN
		 Customer C on o.CUSTOMER_ID = C.ID
    ) AS SourceTable
PIVOT
    (
        ROUND(SUM(TotalProfit),2)
        FOR QUARTER_YEAR IN (' + @QuartersList + ')
    ) AS PivotTable
ORDER BY 
    State;
';

-- Execute the dynamic SQL with parameters
EXEC sp_executesql @DynamicSQL, 
                   N'@StartDate DATE, @EndDate DATE',  -- Declare the parameters
                   @StartDate, @EndDate;             -- Pass the parameters
--EXEC (@DynamicSQL);