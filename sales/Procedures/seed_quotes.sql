-- Generuje przykładowe oferty z pozycjami rozłożone na ostatnie @weeks tygodni.
-- 70% ofert trafia do klientów z projektami (i w ~60% do jednego z ich projektów), reszta do losowych klientów.
-- Status zależy od wieku oferty: świeże są draft / sent, starsze accepted / rejected / expired.
-- Zaakceptowane oferty zamienia w zamówienia sales.seed_orders_from_quotes.
-- Kolejne uruchomienia dokładają oferty (numeracja SEED-Q<n> kontynuowana).
--
--   EXEC sales.seed_quotes;                                   -- 26 tygodni, średnio 15 ofert na tydzień
--   EXEC sales.seed_quotes @weeks = 52, @quotes_per_week = 30;
CREATE PROCEDURE [sales].[seed_quotes]
    @weeks           INT = 26,
    @quotes_per_week INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @weeks IS NULL OR @weeks NOT BETWEEN 1 AND 520
        THROW 50001, N'@weeks musi być w zakresie 1..520.', 1;
    IF @quotes_per_week IS NULL OR @quotes_per_week NOT BETWEEN 1 AND 1000
        THROW 50002, N'@quotes_per_week musi być w zakresie 1..1000.', 1;

    ---------------------------------------------------------------------------------------------
    -- 1. Pule do losowania
    ---------------------------------------------------------------------------------------------
    CREATE TABLE #clients ([rn] INT NOT NULL PRIMARY KEY, [client_id] BIGINT NOT NULL);
    INSERT INTO #clients ([rn], [client_id])
    SELECT ROW_NUMBER() OVER (ORDER BY c.[id]), c.[id]
    FROM [crm].[clients] AS c
    WHERE c.[deleted_at] IS NULL
      AND c.[status] IN ('active', 'prospect', 'inactive');

    -- Klienci z projektami — oferty w projektach są typowe dla B2B.
    CREATE TABLE #project_clients ([rn] INT NOT NULL PRIMARY KEY, [client_id] BIGINT NOT NULL);
    INSERT INTO #project_clients ([rn], [client_id])
    SELECT ROW_NUMBER() OVER (ORDER BY x.[client_id]), x.[client_id]
    FROM (SELECT DISTINCT p.[client_id] FROM [crm].[projects] AS p WHERE p.[status] <> 'cancelled') AS x;

    CREATE TABLE #products
    (
        [rn] INT NOT NULL PRIMARY KEY, [product_id] BIGINT NOT NULL, [product_kind] VARCHAR(20) NOT NULL,
        [unit_code] VARCHAR(20) NOT NULL, [list_price] DECIMAL(19, 4) NOT NULL
    );
    INSERT INTO #products ([rn], [product_id], [product_kind], [unit_code], [list_price])
    SELECT ROW_NUMBER() OVER (ORDER BY p.[id]), p.[id], p.[product_kind], p.[unit_code], p.[list_price]
    FROM [catalog].[products] AS p
    WHERE p.[is_active] = 1;

    DECLARE @client_count INT = (SELECT COUNT(*) FROM #clients);
    DECLARE @project_client_count INT = (SELECT COUNT(*) FROM #project_clients);
    DECLARE @product_count INT = (SELECT COUNT(*) FROM #products);

    IF @client_count = 0
        THROW 50003, N'Brak klientów o statusie active / prospect / inactive — najpierw uruchom crm.seed_clients.', 1;
    IF @product_count = 0
        THROW 50004, N'Brak aktywnych produktów w katalogu — najpierw uruchom catalog.seed_products.', 1;

    DECLARE @quote_count INT = @weeks * @quotes_per_week;
    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @span_seconds INT = @weeks * 7 * 86400;

    ---------------------------------------------------------------------------------------------
    -- 2. Losowe wartości nagłówków (zapisane raz)
    ---------------------------------------------------------------------------------------------
    WITH [digits] AS (
        SELECT [d] FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v([d])
    ),
    [numbers] AS (
        SELECT TOP (@quote_count) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS [n]
        FROM [digits] a CROSS JOIN [digits] b CROSS JOIN [digits] c CROSS JOIN [digits] d CROSS JOIN [digits] e CROSS JOIN [digits] f
    )
    SELECT
        n.[n],
        DATEADD(SECOND, -CAST(@span_seconds * (1 - SQRT((ABS(CHECKSUM(NEWID())) % 1000000) / 1000000.0)) AS INT), @now) AS [created_at],
        (ABS(CHECKSUM(NEWID())) % @client_count) + 1 AS [client_rn],
        CASE WHEN @project_client_count > 0 THEN (ABS(CHECKSUM(NEWID())) % @project_client_count) + 1 END AS [project_client_rn],
        ABS(CHECKSUM(NEWID())) % 100      AS [r_pool],
        ABS(CHECKSUM(NEWID())) % 100      AS [r_status],
        ABS(CHECKSUM(NEWID())) % 100      AS [r_project],
        (ABS(CHECKSUM(NEWID())) % 5) + 1  AS [line_count],
        ABS(CHECKSUM(NEWID())) % 100      AS [r_discount]
    INTO #rnd_quotes
    FROM [numbers] AS n;

    BEGIN TRANSACTION;

    DECLARE @offset BIGINT = ISNULL((
        SELECT MAX(CAST(SUBSTRING(q.[quote_number], 7, 24) AS BIGINT))
        FROM [sales].[quotes] AS q WITH (UPDLOCK, HOLDLOCK)
        WHERE q.[quote_number] LIKE 'SEED-Q%'), 0);

    SELECT
        r.[n],
        CONCAT('SEED-Q', RIGHT(CONCAT('0000000', @offset + r.[n]), 7)) AS [quote_number],
        COALESCE(pc.[client_id], c.[client_id]) AS [client_id],
        r.[created_at],
        r.[r_status],
        r.[r_project],
        r.[line_count],
        CASE WHEN r.[r_discount] < 50 THEN 0 WHEN r.[r_discount] < 80 THEN 5 WHEN r.[r_discount] < 95 THEN 10 ELSE 15 END AS [discount]
    INTO #quotes
    FROM #rnd_quotes AS r
    JOIN #clients AS c
        ON c.[rn] = r.[client_rn]
    LEFT JOIN #project_clients AS pc
        ON pc.[rn] = r.[project_client_rn]
       AND r.[r_pool] < 70;

    INSERT INTO [sales].[quotes] ([quote_number], [client_id], [project_id], [status], [currency_code], [valid_until], [notes], [created_at])
    SELECT
        q.[quote_number],
        q.[client_id],
        CASE WHEN q.[r_project] < 60 THEN pr.[id] END,
        CASE
            WHEN DATEDIFF(DAY, q.[created_at], @now) <= 2  THEN CASE WHEN q.[r_status] < 50 THEN 'draft' ELSE 'sent' END
            WHEN DATEDIFF(DAY, q.[created_at], @now) <= 30 THEN CASE WHEN q.[r_status] < 40 THEN 'sent'
                                                                     WHEN q.[r_status] < 75 THEN 'accepted'
                                                                     ELSE 'rejected' END
            ELSE CASE WHEN q.[r_status] < 50 THEN 'accepted' WHEN q.[r_status] < 75 THEN 'rejected' ELSE 'expired' END
        END,
        'PLN',
        DATEADD(DAY, 30, CAST(q.[created_at] AS DATE)),
        N'Oferta testowa - wygenerowana przez sales.seed_quotes',
        q.[created_at]
    FROM #quotes AS q
    OUTER APPLY (
        SELECT TOP (1) p.[id]
        FROM [crm].[projects] AS p
        WHERE p.[client_id] = q.[client_id]
          AND p.[status] <> 'cancelled'
        ORDER BY (q.[n] * 7919 + p.[id]) % 97
    ) AS pr
    ORDER BY q.[created_at];

    DECLARE @inserted_quotes INT = @@ROWCOUNT;

    ---------------------------------------------------------------------------------------------
    -- 3. Pozycje ofert: 1..5, cena = cena katalogowa w chwili ofertowania
    ---------------------------------------------------------------------------------------------
    WITH [line_numbers] AS (
        SELECT [line_no] FROM (VALUES (1),(2),(3),(4),(5)) AS v([line_no])
    )
    SELECT
        sq.[id] AS [quote_id],
        q.[created_at],
        q.[discount],
        ln.[line_no],
        (ABS(CHECKSUM(NEWID())) % @product_count) + 1 AS [product_rn],
        ABS(CHECKSUM(NEWID())) % 1000                AS [r_qty]
    INTO #rnd_lines
    FROM #quotes AS q
    JOIN [sales].[quotes] AS sq
        ON sq.[quote_number] = q.[quote_number]
    JOIN [line_numbers] AS ln
        ON ln.[line_no] <= q.[line_count];

    INSERT INTO [sales].[quote_lines] ([quote_id], [line_no], [product_id], [quantity], [unit_price], [discount_percent], [service_from], [service_to])
    SELECT
        r.[quote_id],
        r.[line_no],
        p.[product_id],
        CASE p.[product_kind]
            WHEN 'hardware' THEN 1 + r.[r_qty] % 20
            WHEN 'license'  THEN 5 + r.[r_qty] % 96
            WHEN 'support'  THEN 1 + r.[r_qty] % 12
            ELSE                 1 + r.[r_qty] % 3
        END,
        CASE WHEN p.[unit_code] = 'usage' THEN 500 + (r.[r_qty] % 451) * 10 ELSE p.[list_price] END,
        r.[discount],
        CASE WHEN p.[product_kind] <> 'hardware' THEN CAST(r.[created_at] AS DATE) END,
        CASE WHEN p.[product_kind] <> 'hardware' THEN DATEADD(DAY, -1, DATEADD(YEAR, 1, CAST(r.[created_at] AS DATE))) END
    FROM #rnd_lines AS r
    JOIN #products AS p
        ON p.[rn] = r.[product_rn];

    DECLARE @inserted_lines INT = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @inserted_quotes AS [inserted_quotes], @inserted_lines AS [inserted_lines];
END;
