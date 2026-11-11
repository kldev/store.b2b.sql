-- Realizacja zamówień w toku i zakończonych (in_fulfillment, completed):
--   * sales.delivered_devices — egzemplarze sprzętu z numerami seryjnymi i gwarancją z katalogu;
--     zamówienie zakończone ma dostarczone wszystkie sztuki, w toku — połowę (w górę);
--   * sales.subscriptions — usługi w czasie: licencje subskrypcyjne, wsparcie miesięczne / roczne, chmura.
-- Idempotentna: pomija pozycje, które mają już egzemplarze albo subskrypcję. Działa na wszystkich zamówieniach.
--
--   EXEC sales.seed_fulfillment;
CREATE PROCEDURE [sales].[seed_fulfillment]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);

    BEGIN TRANSACTION;

    ---------------------------------------------------------------------------------------------
    -- 1. Dostarczone egzemplarze sprzętu (do 50 sztuk na pozycję)
    ---------------------------------------------------------------------------------------------
    WITH [digits] AS (
        SELECT [d] FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v([d])
    ),
    [units] AS (
        SELECT a.[d] * 10 + b.[d] + 1 AS [unit_no]
        FROM [digits] a CROSS JOIN [digits] b
        WHERE a.[d] * 10 + b.[d] + 1 <= 50
    ),
    [lines] AS (
        SELECT
            ol.[id] AS [order_line_id],
            p.[manufacturer_code],
            hd.[warranty_months],
            -- Dostawa 2..10 dni po zamówieniu, nie później niż dziś.
            CASE WHEN DATEADD(DAY, 2 + ol.[id] % 9, CAST(o.[ordered_at] AS DATE)) > @today THEN @today
                 ELSE DATEADD(DAY, 2 + ol.[id] % 9, CAST(o.[ordered_at] AS DATE)) END AS [delivered_on],
            CASE WHEN o.[status] = 'completed' THEN CAST(FLOOR(ol.[quantity]) AS INT)
                 ELSE CAST(CEILING(FLOOR(ol.[quantity]) / 2.0) AS INT) END AS [delivered_qty]
        FROM [sales].[order_lines] AS ol
        JOIN [sales].[orders] AS o
            ON o.[id] = ol.[order_id]
        JOIN [catalog].[products] AS p
            ON p.[id] = ol.[product_id]
        JOIN [catalog].[hardware_details] AS hd
            ON hd.[product_id] = p.[id]
        WHERE o.[status] IN ('in_fulfillment', 'completed')
          AND NOT EXISTS (SELECT 1 FROM [sales].[delivered_devices] AS dd WHERE dd.[order_line_id] = ol.[id])
    )
    INSERT INTO [sales].[delivered_devices] ([order_line_id], [serial_number], [delivered_on], [warranty_until])
    SELECT
        l.[order_line_id],
        CONCAT('SN-', ISNULL(l.[manufacturer_code], 'X'), '-', RIGHT(CONCAT('00000000', l.[order_line_id]), 8), '-', RIGHT(CONCAT('0', u.[unit_no]), 2)),
        l.[delivered_on],
        CASE WHEN l.[warranty_months] > 0
             THEN DATEADD(DAY, -1, DATEADD(MONTH, l.[warranty_months], l.[delivered_on])) END
    FROM [lines] AS l
    JOIN [units] AS u
        ON u.[unit_no] <= l.[delivered_qty];

    DECLARE @inserted_devices INT = @@ROWCOUNT;

    ---------------------------------------------------------------------------------------------
    -- 2. Subskrypcje / umowy w czasie
    ---------------------------------------------------------------------------------------------
    WITH [src] AS (
        SELECT
            o.[client_id],
            o.[project_id],
            ol.[product_id],
            ol.[id] AS [order_line_id],
            ol.[quantity],
            p.[product_kind],
            p.[manufacturer_code],
            p.[cloud_provider_code],
            COALESCE(ol.[service_from], CAST(o.[ordered_at] AS DATE)) AS [start_date],
            COALESCE(ol.[service_to],
                     DATEADD(DAY, -1, DATEADD(YEAR, 1, COALESCE(ol.[service_from], CAST(o.[ordered_at] AS DATE))))) AS [end_date]
        FROM [sales].[order_lines] AS ol
        JOIN [sales].[orders] AS o
            ON o.[id] = ol.[order_id]
        JOIN [catalog].[products] AS p
            ON p.[id] = ol.[product_id]
        LEFT JOIN [catalog].[license_details] AS ld
            ON ld.[product_id] = p.[id]
        LEFT JOIN [catalog].[support_details] AS sd
            ON sd.[product_id] = p.[id]
        WHERE o.[status] IN ('in_fulfillment', 'completed')
          AND (   (p.[product_kind] = 'license' AND ld.[license_model] = 'subscription')
               OR (p.[product_kind] = 'support' AND sd.[billing_period] IN ('monthly', 'yearly'))
               OR  p.[product_kind] = 'cloud')
          AND NOT EXISTS (SELECT 1 FROM [sales].[subscriptions] AS s WHERE s.[order_line_id] = ol.[id])
    )
    INSERT INTO [sales].[subscriptions] ([client_id], [project_id], [product_id], [order_line_id], [quantity], [start_date], [end_date], [auto_renew], [status], [vendor_reference])
    SELECT
        s.[client_id],
        s.[project_id],
        s.[product_id],
        s.[order_line_id],
        s.[quantity],
        s.[start_date],
        s.[end_date],
        CASE WHEN s.[order_line_id] % 2 = 0 THEN 1 ELSE 0 END,
        CASE
            WHEN s.[end_date] < @today THEN 'expired'
            WHEN s.[order_line_id] % 20 = 0 THEN 'cancelled'
            WHEN s.[order_line_id] % 20 = 1 THEN 'suspended'
            ELSE 'active'
        END,
        CASE s.[product_kind]
            WHEN 'cloud'   THEN CONCAT(s.[cloud_provider_code], N'-SUB-', RIGHT(CONCAT('00000000', s.[order_line_id]), 8))
            WHEN 'license' THEN CONCAT(s.[manufacturer_code], N'-AGR-', RIGHT(CONCAT('00000000', s.[order_line_id]), 8))
        END
    FROM [src] AS s;

    DECLARE @inserted_subscriptions INT = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @inserted_devices AS [inserted_delivered_devices], @inserted_subscriptions AS [inserted_subscriptions];
END;
