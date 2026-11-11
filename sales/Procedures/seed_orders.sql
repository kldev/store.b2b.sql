-- Generuje przykładowe zamówienia z pozycjami rozłożone losowo na ostatnie @weeks tygodni,
-- żeby widoki app.orders i app.orders_by_week miały dane.
-- Klient losowany (połowa spośród klientów z projektami), produkt losowy; projekt — jeden z rozpoczętych projektów klienta.
-- Gdy katalog albo klienci są puści, najpierw woła catalog.seed_products / crm.seed_clients.
-- Kolejne uruchomienia dokładają zamówienia (numeracja SEED-<n> kontynuowana, bez dubli).
--
--   EXEC sales.seed_orders;                                   -- 26 tygodni, średnio 25 zamówień na tydzień
--   EXEC sales.seed_orders @weeks = 52, @orders_per_week = 40;
CREATE PROCEDURE [sales].[seed_orders]
    @weeks           INT = 26,   -- ile tygodni wstecz od dziś
    @orders_per_week INT = 25    -- średnia liczba zamówień na tydzień (rzeczywista waha się losowo)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @weeks IS NULL OR @weeks NOT BETWEEN 1 AND 520
        THROW 50001, N'@weeks musi być w zakresie 1..520.', 1;
    IF @orders_per_week IS NULL OR @orders_per_week NOT BETWEEN 1 AND 1000
        THROW 50002, N'@orders_per_week musi być w zakresie 1..1000.', 1;

    ---------------------------------------------------------------------------------------------
    -- 1. Dane, od których zależą zamówienia
    ---------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM [catalog].[products] WHERE [is_active] = 1)
        EXEC [catalog].[seed_products];
    IF NOT EXISTS (SELECT 1 FROM [crm].[clients] WHERE [deleted_at] IS NULL)
        EXEC [crm].[seed_clients] @count = 500;

    -- Pule do losowania: numer kolejny 1..N, żeby wybrać wiersz przez (losowa % N) + 1.
    CREATE TABLE #clients ([rn] INT NOT NULL PRIMARY KEY, [client_id] BIGINT NOT NULL);
    INSERT INTO #clients ([rn], [client_id])
    SELECT ROW_NUMBER() OVER (ORDER BY c.[id]), c.[id]
    FROM [crm].[clients] AS c
    WHERE c.[deleted_at] IS NULL
      AND c.[status] IN ('active', 'prospect', 'inactive');   -- zamawiają klienci, nie leady

    -- Klienci z projektami: połowa zamówień trafia do nich, żeby sprzedaż w projektach miała dane.
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
    DECLARE @product_count INT = (SELECT COUNT(*) FROM #products);
    DECLARE @project_client_count INT = (SELECT COUNT(*) FROM #project_clients);

    IF @client_count = 0
        THROW 50003, N'Brak klientów o statusie active / prospect / inactive — nie ma komu wystawić zamówień.', 1;
    IF @product_count = 0
        THROW 50004, N'Brak aktywnych produktów w katalogu.', 1;

    ---------------------------------------------------------------------------------------------
    -- 2. Nagłówki zamówień (losowe wartości materializowane raz, w tabeli tymczasowej)
    ---------------------------------------------------------------------------------------------
    DECLARE @order_count INT = @weeks * @orders_per_week;
    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @span_seconds INT = @weeks * 7 * 86400;

    CREATE TABLE #orders
    (
        [n]            INT          NOT NULL PRIMARY KEY,
        [order_number] VARCHAR(30)  NOT NULL,
        [client_id]    BIGINT       NOT NULL,
        [project_id]   BIGINT       NULL,
        [ordered_at]   DATETIME2(3) NOT NULL,
        [status]       VARCHAR(20)  NOT NULL,
        [line_count]   INT          NOT NULL,
        [discount]     DECIMAL(5, 2) NOT NULL
    );

    BEGIN TRANSACTION;

    -- Numeracja kontynuowana od największego numeru SEED-; blokada, żeby dwa wywołania naraz nie wzięły tej samej.
    DECLARE @offset BIGINT = ISNULL((
        SELECT MAX(CAST(SUBSTRING(o.[order_number], 6, 25) AS BIGINT))
        FROM [sales].[orders] AS o WITH (UPDLOCK, HOLDLOCK)
        WHERE o.[order_number] LIKE 'SEED-%'), 0);

    WITH [digits] AS (
        SELECT [d] FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v([d])
    ),
    [numbers] AS (
        SELECT TOP (@order_count) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT) AS [n]
        FROM [digits] a CROSS JOIN [digits] b CROSS JOIN [digits] c CROSS JOIN [digits] d CROSS JOIN [digits] e CROSS JOIN [digits] f
    ),
    [rnd] AS (
        SELECT
            n.[n],
            -- Losowa chwila w oknie: im wyżej r_time, tym bliżej dziś. Pierwiastek przesuwa rozkład
            -- ku teraźniejszości — liczba zamówień tygodniowo lekko rośnie (trend sprzedaży).
            DATEADD(SECOND, -CAST(@span_seconds * (1 - SQRT((ABS(CHECKSUM(NEWID())) % 1000000) / 1000000.0)) AS INT), @now) AS [ordered_at],
            (ABS(CHECKSUM(NEWID())) % @client_count) + 1 AS [client_rn],
            CASE WHEN @project_client_count > 0 THEN (ABS(CHECKSUM(NEWID())) % @project_client_count) + 1 END AS [project_client_rn],
            ABS(CHECKSUM(NEWID())) % 100                AS [r_pool],
            ABS(CHECKSUM(NEWID())) % 100                AS [r_status],
            ABS(CHECKSUM(NEWID())) % 100                AS [r_project],
            (ABS(CHECKSUM(NEWID())) % 5) + 1            AS [line_count],
            ABS(CHECKSUM(NEWID())) % 100                AS [r_discount]
        FROM [numbers] AS n
    )
    -- NEWID() w CTE liczy się od nowa przy każdym użyciu (np. w każdym porównaniu joinu),
    -- więc losowe wartości najpierw zapisujemy, a dopiero potem łączymy z pulami.
    SELECT [n], [ordered_at], [client_rn], [project_client_rn], [r_pool], [r_status], [r_project], [line_count], [r_discount]
    INTO #rnd_raw
    FROM [rnd];

    SELECT r.[n], r.[ordered_at], COALESCE(pc.[client_id], c.[client_id]) AS [client_id],
           r.[r_status], r.[r_project], r.[line_count], r.[r_discount]
    INTO #rnd_orders
    FROM #rnd_raw AS r
    JOIN #clients AS c
        ON c.[rn] = r.[client_rn]
    LEFT JOIN #project_clients AS pc
        ON pc.[rn] = r.[project_client_rn]
       AND r.[r_pool] < 50;

    INSERT INTO #orders ([n], [order_number], [client_id], [project_id], [ordered_at], [status], [line_count], [discount])
    SELECT
        r.[n],
        CONCAT('SEED-', RIGHT(CONCAT('0000000', @offset + r.[n]), 7)),
        r.[client_id],
        CASE WHEN r.[r_project] < 60 THEN pr.[id] END,       -- ~60% zamówień w ramach projektu (jeśli klient go ma)
        r.[ordered_at],
        -- Status zależy od wieku zamówienia: stare są zamknięte, świeże jeszcze w toku.
        CASE
            WHEN r.[r_status] < 7 THEN 'cancelled'
            WHEN DATEDIFF(DAY, r.[ordered_at], @now) > 28 THEN 'completed'
            WHEN DATEDIFF(DAY, r.[ordered_at], @now) > 14 THEN CASE WHEN r.[r_status] < 60 THEN 'completed' ELSE 'in_fulfillment' END
            WHEN DATEDIFF(DAY, r.[ordered_at], @now) > 3  THEN CASE WHEN r.[r_status] < 50 THEN 'in_fulfillment' ELSE 'confirmed' END
            ELSE CASE WHEN r.[r_status] < 60 THEN 'new' ELSE 'confirmed' END
        END,
        r.[line_count],
        CASE WHEN r.[r_discount] < 60 THEN 0 WHEN r.[r_discount] < 85 THEN 5 WHEN r.[r_discount] < 95 THEN 10 ELSE 15 END
    FROM #rnd_orders AS r
    OUTER APPLY (
        SELECT TOP (1) p.[id]
        FROM [crm].[projects] AS p
        WHERE p.[client_id] = r.[client_id]
          AND p.[status] <> 'cancelled'
          AND p.[start_date] <= CAST(r.[ordered_at] AS DATE)   -- zamówienie w projekcie, który już ruszył
        ORDER BY (r.[n] * 7919 + p.[id]) % 97   -- deterministyczny "losowy" wybór projektu dla wiersza
    ) AS pr;

    INSERT INTO [sales].[orders] ([order_number], [client_id], [project_id], [status], [currency_code], [ordered_at], [customer_po], [notes])
    SELECT
        o.[order_number], o.[client_id], o.[project_id], o.[status], 'PLN', o.[ordered_at],
        CASE WHEN o.[n] % 3 = 0 THEN CONCAT(N'PO/', YEAR(o.[ordered_at]), N'/', o.[n]) END,
        N'Zamówienie testowe - wygenerowane przez sales.seed_orders'
    FROM #orders AS o
    ORDER BY o.[ordered_at];

    DECLARE @inserted_orders INT = @@ROWCOUNT;

    ---------------------------------------------------------------------------------------------
    -- 3. Pozycje: 1..5 na zamówienie, produkt losowy, cena = cena katalogowa w chwili sprzedaży
    ---------------------------------------------------------------------------------------------
    WITH [line_numbers] AS (
        SELECT [line_no] FROM (VALUES (1),(2),(3),(4),(5)) AS v([line_no])
    ),
    [rnd] AS (
        SELECT
            so.[id] AS [order_id],
            o.[ordered_at],
            o.[discount],
            ln.[line_no],
            (ABS(CHECKSUM(NEWID())) % @product_count) + 1 AS [product_rn],
            ABS(CHECKSUM(NEWID())) % 1000                AS [r_qty]
        FROM #orders AS o
        JOIN [sales].[orders] AS so
            ON so.[order_number] = o.[order_number]
        JOIN [line_numbers] AS ln
            ON ln.[line_no] <= o.[line_count]
    )
    SELECT [order_id], [ordered_at], [discount], [line_no], [product_rn], [r_qty]
    INTO #rnd_lines
    FROM [rnd];

    INSERT INTO [sales].[order_lines] ([order_id], [line_no], [product_id], [quantity], [unit_price], [discount_percent], [service_from], [service_to])
    SELECT
        r.[order_id],
        r.[line_no],
        p.[product_id],
        CASE p.[product_kind]
            WHEN 'hardware' THEN 1 + r.[r_qty] % 20    -- sztuki
            WHEN 'license'  THEN 5 + r.[r_qty] % 96    -- stanowiska / rdzenie
            WHEN 'support'  THEN 1 + r.[r_qty] % 12    -- godziny / miesiące
            ELSE                 1 + r.[r_qty] % 3     -- chmura
        END,
        -- Rozliczenie wg zużycia nie ma ceny katalogowej — szacunek miesięczny 500..5000 PLN.
        CASE WHEN p.[unit_code] = 'usage' THEN 500 + (r.[r_qty] % 451) * 10 ELSE p.[list_price] END,
        r.[discount],
        -- Licencje, wsparcie i chmura mają okres usługi: rok od dnia zamówienia.
        CASE WHEN p.[product_kind] <> 'hardware' THEN CAST(r.[ordered_at] AS DATE) END,
        CASE WHEN p.[product_kind] <> 'hardware' THEN DATEADD(DAY, -1, DATEADD(YEAR, 1, CAST(r.[ordered_at] AS DATE))) END
    FROM #rnd_lines AS r
    JOIN #products AS p
        ON p.[rn] = r.[product_rn];

    DECLARE @inserted_lines INT = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @inserted_orders AS [inserted_orders], @inserted_lines AS [inserted_lines];
END;
