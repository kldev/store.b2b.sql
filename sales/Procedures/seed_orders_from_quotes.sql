-- Zamienia zaakceptowane oferty, które nie mają jeszcze zamówienia, w zamówienia (proces quote → order).
-- Zamówienie dziedziczy klienta, projekt i walutę oferty; pozycje i ceny są kopiowane z oferty 1:1.
-- Data zamówienia: 1..7 dni po ofercie (nie później niż teraz); status zależy od wieku jak w sales.seed_orders.
-- Działa na każdej zaakceptowanej ofercie bez zamówienia, nie tylko SEED-Q; numeracja zamówień SEED-<n> kontynuowana.
--
--   EXEC sales.seed_orders_from_quotes;
CREATE PROCEDURE [sales].[seed_orders_from_quotes]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    -- Losowe wartości zapisane raz.
    SELECT
        q.[id] AS [quote_id],
        q.[client_id],
        q.[project_id],
        q.[currency_code],
        q.[created_at],
        1 + ABS(CHECKSUM(NEWID())) % 7 AS [r_days],
        ABS(CHECKSUM(NEWID())) % 100   AS [r_status]
    INTO #rnd
    FROM [sales].[quotes] AS q
    WHERE q.[status] = 'accepted'
      AND NOT EXISTS (SELECT 1 FROM [sales].[orders] AS o WHERE o.[quote_id] = q.[id]);

    BEGIN TRANSACTION;

    DECLARE @offset BIGINT = ISNULL((
        SELECT MAX(CAST(SUBSTRING(o.[order_number], 6, 25) AS BIGINT))
        FROM [sales].[orders] AS o WITH (UPDLOCK, HOLDLOCK)
        WHERE o.[order_number] LIKE 'SEED-%'), 0);

    SELECT
        r.[quote_id],
        r.[client_id],
        r.[project_id],
        r.[currency_code],
        r.[r_status],
        CONCAT('SEED-', RIGHT(CONCAT('0000000', @offset + ROW_NUMBER() OVER (ORDER BY r.[created_at], r.[quote_id])), 7)) AS [order_number],
        CASE WHEN DATEADD(DAY, r.[r_days], r.[created_at]) > @now THEN @now
             ELSE DATEADD(DAY, r.[r_days], r.[created_at]) END AS [ordered_at]
    INTO #orders
    FROM #rnd AS r;

    INSERT INTO [sales].[orders] ([order_number], [client_id], [project_id], [quote_id], [status], [currency_code], [ordered_at], [notes])
    SELECT
        o.[order_number],
        o.[client_id],
        o.[project_id],
        o.[quote_id],
        CASE
            WHEN o.[r_status] < 3 THEN 'cancelled'
            WHEN DATEDIFF(DAY, o.[ordered_at], @now) > 28 THEN 'completed'
            WHEN DATEDIFF(DAY, o.[ordered_at], @now) > 14 THEN CASE WHEN o.[r_status] < 60 THEN 'completed' ELSE 'in_fulfillment' END
            WHEN DATEDIFF(DAY, o.[ordered_at], @now) > 3  THEN CASE WHEN o.[r_status] < 50 THEN 'in_fulfillment' ELSE 'confirmed' END
            ELSE CASE WHEN o.[r_status] < 60 THEN 'new' ELSE 'confirmed' END
        END,
        o.[currency_code],
        o.[ordered_at],
        N'Zamówienie testowe z oferty - wygenerowane przez sales.seed_orders_from_quotes'
    FROM #orders AS o
    ORDER BY o.[ordered_at];

    DECLARE @inserted_orders INT = @@ROWCOUNT;

    INSERT INTO [sales].[order_lines] ([order_id], [line_no], [product_id], [description], [quantity], [unit_price], [discount_percent], [service_from], [service_to])
    SELECT so.[id], ql.[line_no], ql.[product_id], ql.[description], ql.[quantity], ql.[unit_price], ql.[discount_percent], ql.[service_from], ql.[service_to]
    FROM #orders AS o
    JOIN [sales].[orders] AS so
        ON so.[order_number] = o.[order_number]
    JOIN [sales].[quote_lines] AS ql
        ON ql.[quote_id] = o.[quote_id];

    DECLARE @inserted_lines INT = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @inserted_orders AS [inserted_orders_from_quotes], @inserted_lines AS [inserted_lines];
END;
