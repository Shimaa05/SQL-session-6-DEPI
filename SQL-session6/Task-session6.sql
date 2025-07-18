use StoreDB;
Go

DECLARE @CustomerID INT = 1;
DECLARE @TotalSpent MONEY;

SELECT @TotalSpent = SUM(OI.quantity * OI.list_price)
FROM sales.orders O
JOIN sales.order_items OI ON O.order_id = OI.order_id
WHERE O.customer_id = @CustomerID;

IF @TotalSpent > 5000
    PRINT 'Customer is a VIP. Total Spent: $' + CAST(@TotalSpent AS VARCHAR);
ELSE
    PRINT 'Customer is Regular. Total Spent: $' + CAST(@TotalSpent AS VARCHAR);

----------------------------------------------------

DECLARE @Threshold MONEY = 1500;
DECLARE @ProductCount INT;

SELECT @ProductCount = COUNT(*)
FROM production.products
WHERE list_price > @Threshold;

PRINT 'Price Threshold: $' + CAST(@Threshold AS VARCHAR) + 
      ' | Products Above Threshold: ' + CAST(@ProductCount AS VARCHAR);

-------------------------------------------------

DECLARE @StaffID INT = 2;
DECLARE @TargetYear INT = 2017;
DECLARE @TotalSales MONEY;

SELECT @TotalSales = SUM(OI.quantity * OI.list_price)
FROM sales.orders O
JOIN sales.order_items OI ON O.order_id = OI.order_id
WHERE O.staff_id = @StaffID AND YEAR(O.order_date) = @TargetYear;

PRINT 'Staff ID: ' + CAST(@StaffID AS VARCHAR);
PRINT 'Year: ' + CAST(@TargetYear AS VARCHAR);
PRINT 'Total Sales: $' + CAST(@TotalSales AS VARCHAR);

-------------------------------------------------

SELECT 
    @@SERVERNAME AS ServerName,
    @@VERSION AS SqlVersion,
    @@ROWCOUNT AS RowsAffected;

-------------------------------------------------

DECLARE @ProductID INT = 1;
DECLARE @StoreID INT = 1;
DECLARE @Quantity INT;

SELECT @Quantity = quantity
FROM production.stocks
WHERE product_id = @ProductID AND store_id = @StoreID;

IF @Quantity > 20
    PRINT 'Well stocked';
ELSE IF @Quantity BETWEEN 10 AND 20
    PRINT 'Moderate stock';
ELSE IF @Quantity < 10
    PRINT 'Low stock - reorder needed';
ELSE
    PRINT 'Product not found or no quantity data';

-------------------------------------------------

DECLARE @BatchSize INT = 3;
DECLARE @Counter INT = 0;

WHILE EXISTS (
    SELECT 1
    FROM production.stocks
    WHERE quantity < 5
)
BEGIN
    -- تحديث أول 3 منتجات منخفضة المخزون
    UPDATE TOP (@BatchSize) production.stocks
    SET quantity = quantity + 10
    WHERE quantity < 5;

    SET @Counter += 1;

    PRINT 'Batch ' + CAST(@Counter AS VARCHAR) + ' updated: Added 10 units to 3 products.';
END

PRINT 'Stock update completed.';

-------------------------------------------------

SELECT 
    product_name,
    list_price,
    Category = 
        CASE 
            WHEN list_price < 300 THEN 'Budget'
            WHEN list_price BETWEEN 300 AND 800 THEN 'Mid-Range'
            WHEN list_price BETWEEN 801 AND 2000 THEN 'Premium'
            ELSE 'Luxury'
        END
FROM production.products;

-------------------------------------------------

DECLARE @CustomerID INT = 5;
DECLARE @OrderCount INT;

IF EXISTS (
    SELECT 1 FROM sales.customers WHERE customer_id = @CustomerID
)
BEGIN
    SELECT @OrderCount = COUNT(*) 
    FROM sales.orders 
    WHERE customer_id = @CustomerID;

    PRINT 'Customer ID ' + CAST(@CustomerID AS VARCHAR) + 
          ' has ' + CAST(@OrderCount AS VARCHAR) + ' orders.';
END
ELSE
BEGIN
    PRINT 'Customer ID ' + CAST(@CustomerID AS VARCHAR) + ' does not exist.';
END

-------------------------------------------------

CREATE FUNCTION dbo.CalculateShipping (@OrderTotal MONEY)
RETURNS MONEY
AS
BEGIN
    DECLARE @ShippingCost MONEY;

    IF @OrderTotal > 100
        SET @ShippingCost = 0;
    ELSE IF @OrderTotal BETWEEN 50 AND 99.99
        SET @ShippingCost = 5.99;
    ELSE
        SET @ShippingCost = 12.99;

    RETURN @ShippingCost;
END

SELECT dbo.CalculateShipping(120);
-------------------------------------------------

CREATE FUNCTION dbo.GetProductsByPriceRange (
    @MinPrice MONEY,
    @MaxPrice MONEY
)
RETURNS TABLE
AS
RETURN
    SELECT 
        P.product_name,
        P.list_price,
        B.brand_name,
        C.category_name
    FROM production.products P
    JOIN production.brands B ON P.brand_id = B.brand_id
    JOIN production.categories C ON P.category_id = C.category_id
    WHERE P.list_price BETWEEN @MinPrice AND @MaxPrice;

SELECT * FROM dbo.GetProductsByPriceRange(500, 1500);

-------------------------------------------------

CREATE FUNCTION dbo.GetCustomerYearlySummary (@CustomerID INT)
RETURNS @Summary TABLE (
    OrderYear INT,
    TotalOrders INT,
    TotalSpent MONEY,
    AverageOrder MONEY
)
AS
BEGIN
    INSERT INTO @Summary
    SELECT 
        YEAR(O.order_date) AS OrderYear,
        COUNT(DISTINCT O.order_id) AS TotalOrders,
        SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) AS TotalSpent,
        AVG(OrderTotal.TotalPerOrder) AS AverageOrder
    FROM sales.orders O
    JOIN sales.order_items OI ON O.order_id = OI.order_id
    JOIN (
        SELECT 
            order_id,
            SUM(quantity * list_price * (1 - discount / 100.0)) AS TotalPerOrder
        FROM sales.order_items
        GROUP BY order_id
    ) AS OrderTotal ON O.order_id = OrderTotal.order_id
    WHERE O.customer_id = @CustomerID
    GROUP BY YEAR(O.order_date);

    RETURN;
END

SELECT * FROM dbo.GetCustomerYearlySummary(1);

-------------------------------------------------

CREATE FUNCTION dbo.CalculateBulkDiscount (@Quantity INT)
RETURNS INT
AS
BEGIN
    DECLARE @Discount INT;

    IF @Quantity BETWEEN 1 AND 2
        SET @Discount = 0;
    ELSE IF @Quantity BETWEEN 3 AND 5
        SET @Discount = 5;
    ELSE IF @Quantity BETWEEN 6 AND 9
        SET @Discount = 10;
    ELSE
        SET @Discount = 15;

    RETURN @Discount;
END

SELECT dbo.CalculateBulkDiscount(7);

-------------------------------------------------

CREATE PROCEDURE sp_GetCustomerOrderHistory
    @CustomerID INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        O.order_id,
        O.order_date,
        O.required_date,
        O.shipped_date,
        O.order_status,
        SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) AS OrderTotal
    FROM sales.orders O
    JOIN sales.order_items OI ON O.order_id = OI.order_id
    WHERE O.customer_id = @CustomerID
      AND (@StartDate IS NULL OR O.order_date >= @StartDate)
      AND (@EndDate IS NULL OR O.order_date <= @EndDate)
    GROUP BY 
        O.order_id,
        O.order_date,
        O.required_date,
        O.shipped_date,
        O.order_status
    ORDER BY O.order_date DESC;
END;

EXEC sp_GetCustomerOrderHistory @CustomerID = 2, @StartDate = '2017-01-01', @EndDate = '2017-12-31';

----------------------------------------------------------

CREATE PROCEDURE sp_RestockProduct
    @StoreID INT,
    @ProductID INT,
    @RestockQty INT,
    @OldQty INT OUTPUT,
    @NewQty INT OUTPUT,
    @Success BIT OUTPUT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM production.stocks 
        WHERE store_id = @StoreID AND product_id = @ProductID
    )
    BEGIN
        SELECT @OldQty = quantity
        FROM production.stocks
        WHERE store_id = @StoreID AND product_id = @ProductID;

        UPDATE production.stocks
        SET quantity = quantity + @RestockQty
        WHERE store_id = @StoreID AND product_id = @ProductID;

        SELECT @NewQty = quantity
        FROM production.stocks
        WHERE store_id = @StoreID AND product_id = @ProductID;

        SET @Success = 1;
    END
    ELSE
    BEGIN
        SET @Success = 0;
    END
END

DECLARE @Old INT, @New INT, @Ok BIT;

EXEC sp_RestockProduct 
    @StoreID = 1, @ProductID = 2, @RestockQty = 15,
    @OldQty = @Old OUTPUT, @NewQty = @New OUTPUT, @Success = @Ok OUTPUT;

SELECT @Old AS OldQty, @New AS NewQty, @Ok AS Success;

---------------------------------------------------------------

CREATE PROCEDURE sp_ProcessNewOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT,
    @StoreID INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO sales.orders (customer_id, order_date, store_id)
        VALUES (@CustomerID, GETDATE(), @StoreID);

        DECLARE @OrderID INT = SCOPE_IDENTITY();

        INSERT INTO sales.order_items (order_id, item_id, product_id, quantity, list_price, discount)
        SELECT 
            @OrderID, 
            1, 
            @ProductID, 
            @Quantity, 
            P.list_price, 
            0
        FROM production.products P
        WHERE product_id = @ProductID;

        UPDATE production.stocks
        SET quantity = quantity - @Quantity
        WHERE store_id = @StoreID AND product_id = @ProductID;

        COMMIT TRANSACTION;
        PRINT 'Order processed successfully.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error occurred. Order was not processed.';
    END CATCH
END

EXEC sp_ProcessNewOrder @CustomerID = 1, @ProductID = 3, @Quantity = 2, @StoreID = 1;

---------------------------------------------------------------

CREATE PROCEDURE sp_SearchProducts
    @SearchTerm NVARCHAR(100) = NULL,
    @CategoryID INT = NULL,
    @MinPrice MONEY = NULL,
    @MaxPrice MONEY = NULL,
    @SortColumn NVARCHAR(50) = 'List_Price'
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX)

    SET @SQL = '
        SELECT P.product_id, P.product_name, P.list_price, C.category_name, B.brand_name
        FROM production.products P
        JOIN production.categories C ON P.category_id = C.category_id
        JOIN production.brands B ON P.brand_id = B.brand_id
        WHERE 1 = 1'

    IF @SearchTerm IS NOT NULL
        SET @SQL += ' AND P.product_name LIKE ''%' + @SearchTerm + '%'''

    IF @CategoryID IS NOT NULL
        SET @SQL += ' AND P.category_id = ' + CAST(@CategoryID AS NVARCHAR)

    IF @MinPrice IS NOT NULL
        SET @SQL += ' AND P.list_price >= ' + CAST(@MinPrice AS NVARCHAR)

    IF @MaxPrice IS NOT NULL
        SET @SQL += ' AND P.list_price <= ' + CAST(@MaxPrice AS NVARCHAR)

    SET @SQL += ' ORDER BY ' + QUOTENAME(@SortColumn)

    EXEC sp_executesql @SQL
END

-----------------------------------------------

DECLARE 
    @StartDate DATE = '2017-01-01',
    @EndDate DATE = '2017-03-31',
    @Tier1Rate FLOAT = 0.05,  
    @Tier2Rate FLOAT = 0.03,  
    @Tier3Rate FLOAT = 0.01 

SELECT 
    S.staff_id,
    S.first_name + ' ' + S.last_name AS StaffName,
    SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) AS TotalSales,
    CASE 
        WHEN SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) > 50000 THEN '5% Bonus'
        WHEN SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) BETWEEN 30000 AND 50000 THEN '3% Bonus'
        ELSE '1% Bonus'
    END AS BonusTier
FROM sales.orders O
JOIN sales.order_items OI ON O.order_id = OI.order_id
JOIN sales.staffs S ON O.staff_id = S.staff_id
WHERE O.order_date BETWEEN @StartDate AND @EndDate
GROUP BY S.staff_id, S.first_name, S.last_name
ORDER BY TotalSales DESC

-------------------------------------------------------

SELECT 
    P.product_id,
    P.product_name,
    P.model_year,
    P.list_price,
    I.quantity,
    C.category_name,
    CASE 
        WHEN I.quantity < 5 AND C.category_name = 'Mountain Bikes' THEN 'Reorder 50 Units'
        WHEN I.quantity < 10 AND C.category_name = 'Road Bikes' THEN 'Reorder 30 Units'
        WHEN I.quantity < 8 THEN 'Reorder 20 Units'
        ELSE 'Stock OK'
    END AS RestockAdvice
FROM production.products P
JOIN production.stocks I ON P.product_id = I.product_id
JOIN production.categories C ON P.category_id = C.category_id
WHERE I.store_id = 1

------------------------------------------------

SELECT 
    C.customer_id,
    C.first_name + ' ' + C.last_name AS CustomerName,
    COALESCE(SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)), 0) AS TotalSpent,
    CASE 
        WHEN SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) IS NULL THEN 'No Orders'
        WHEN SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) > 10000 THEN 'Platinum'
        WHEN SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) > 5000 THEN 'Gold'
        WHEN SUM(OI.quantity * OI.list_price * (1 - OI.discount / 100.0)) > 1000 THEN 'Silver'
        ELSE 'Bronze'
    END AS LoyaltyTier
FROM sales.customers C
LEFT JOIN sales.orders O ON C.customer_id = O.customer_id
LEFT JOIN sales.order_items OI ON O.order_id = OI.order_id
GROUP BY C.customer_id, C.first_name, C.last_name

----------------------------------------------------------

CREATE PROCEDURE sp_DiscontinueProduct
    @ProductID INT,
    @ReplacementID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM sales.order_items 
        WHERE product_id = @ProductID
    )
    BEGIN
        IF @ReplacementID IS NOT NULL
        BEGIN
            UPDATE sales.order_items
            SET product_id = @ReplacementID
            WHERE product_id = @ProductID;

            PRINT 'Product replaced in order items.';
        END
        ELSE
        BEGIN
            PRINT 'Cannot discontinue. Product exists in order items and no replacement provided.';
            RETURN;
        END
    END

    UPDATE production.stocks
    SET quantity = 0
    WHERE product_id = @ProductID;

    DELETE FROM production.products
    WHERE product_id = @ProductID;

    PRINT 'Product successfully discontinued.';
END
