-- Tworzy przykładowe projekty klientów (modernizacja serwerowni, migracja do chmury, wymiana laptopów…).
-- Najpierw dostają je klienci, którzy mają już zamówienia (żeby sprzedaż dało się przypiąć do projektu),
-- potem losowi klienci active / prospect / inactive. Każdy wybrany klient dostaje jeden nowy projekt.
-- Na koniec dopina część istniejących zamówień SEED-* bez projektu do projektu ich klienta
-- (tylko gdy projekt zaczął się przed zamówieniem). Prawdziwych zamówień nie rusza.
--
--   EXEC crm.seed_projects;              -- 400 projektów
--   EXEC crm.seed_projects @count = 50;
CREATE PROCEDURE [crm].[seed_projects]
    @count INT = 400   -- ile projektów utworzyć (= ilu klientów dostanie projekt)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @count IS NULL OR @count NOT BETWEEN 1 AND 100000
        THROW 50001, N'@count musi być w zakresie 1..100000.', 1;
    IF NOT EXISTS (SELECT 1 FROM [crm].[clients] WHERE [deleted_at] IS NULL)
        THROW 50002, N'Brak klientów — najpierw uruchom crm.seed_clients.', 1;

    DECLARE @today DATE = CAST(SYSUTCDATETIME() AS DATE);

    ---------------------------------------------------------------------------------------------
    -- 1. Klienci, którzy dostaną projekt
    ---------------------------------------------------------------------------------------------
    CREATE TABLE #candidates ([rn] INT IDENTITY(1, 1) PRIMARY KEY, [client_id] BIGINT NOT NULL UNIQUE);

    INSERT INTO #candidates ([client_id])
    SELECT TOP (@count) x.[client_id]
    FROM (
        SELECT DISTINCT o.[client_id]
        FROM [sales].[orders] AS o
        JOIN [crm].[clients] AS c
            ON c.[id] = o.[client_id]
        WHERE c.[deleted_at] IS NULL
    ) AS x
    ORDER BY NEWID();

    DECLARE @missing INT = @count - @@ROWCOUNT;

    IF @missing > 0
        INSERT INTO #candidates ([client_id])
        SELECT TOP (@missing) c.[id]
        FROM [crm].[clients] AS c
        WHERE c.[deleted_at] IS NULL
          AND c.[status] IN ('active', 'prospect', 'inactive')
          AND NOT EXISTS (SELECT 1 FROM #candidates AS k WHERE k.[client_id] = c.[id])
        ORDER BY NEWID();

    -- Losowe wartości zapisane raz (NEWID() w CTE liczyłby się od nowa przy każdym użyciu).
    SELECT
        k.[rn],
        k.[client_id],
        ABS(CHECKSUM(NEWID())) % 12     AS [r_name],
        ABS(CHECKSUM(NEWID())) % 540    AS [r_start],    -- start od 60 dni w przód do ~16 miesięcy wstecz
        1 + ABS(CHECKSUM(NEWID())) % 12 AS [r_months],   -- czas trwania 1..12 miesięcy
        ABS(CHECKSUM(NEWID())) % 100    AS [r_status]
    INTO #rnd
    FROM #candidates AS k;

    SELECT
        r.[rn],
        r.[client_id],
        r.[r_name],
        r.[r_status],
        DATEADD(DAY, 60 - r.[r_start], @today) AS [start_date],
        -- 15% projektów bez daty końca (utrzymanie, outsourcing).
        CASE WHEN r.[r_status] % 7 = 0 THEN NULL
             ELSE DATEADD(DAY, -1, DATEADD(MONTH, r.[r_months], DATEADD(DAY, 60 - r.[r_start], @today)))
        END AS [end_date]
    INTO #projects
    FROM #rnd AS r;

    BEGIN TRANSACTION;

    ---------------------------------------------------------------------------------------------
    -- 2. Projekty
    ---------------------------------------------------------------------------------------------
    INSERT INTO [crm].[projects] ([client_id], [name], [status], [start_date], [end_date])
    SELECT
        p.[client_id],
        CONCAT(
            CHOOSE(p.[r_name] + 1,
                N'Modernizacja serwerowni', N'Migracja do Microsoft Azure', N'Wymiana stacji roboczych',
                N'Rozbudowa sieci LAN', N'Wdrożenie Microsoft 365', N'Wirtualizacja VMware',
                N'Kopie zapasowe i odtwarzanie (DR)', N'Migracja do AWS', N'Nowe biuro — sieć i Wi-Fi',
                N'Outsourcing helpdesku', N'Wdrożenie Google Workspace', N'Audyt i bezpieczeństwo sieci'),
            N' ', YEAR(p.[start_date])),
        CASE
            WHEN p.[start_date] > @today THEN 'planned'
            WHEN p.[r_status] < 5 THEN 'cancelled'
            WHEN p.[r_status] < 12 THEN 'on_hold'
            WHEN p.[end_date] < @today THEN 'completed'
            ELSE 'active'
        END,
        p.[start_date],
        p.[end_date]
    FROM #projects AS p
    ORDER BY p.[rn];

    DECLARE @inserted_projects INT = @@ROWCOUNT;

    ---------------------------------------------------------------------------------------------
    -- 3. Dopięcie ~60% zamówień SEED-* bez projektu (projekt tego klienta, rozpoczęty przed zamówieniem)
    ---------------------------------------------------------------------------------------------
    UPDATE o
    SET o.[project_id] = pr.[id]
    FROM [sales].[orders] AS o
    CROSS APPLY (
        SELECT TOP (1) p.[id]
        FROM [crm].[projects] AS p
        WHERE p.[client_id] = o.[client_id]
          AND p.[status] <> 'cancelled'
          AND p.[start_date] <= CAST(o.[ordered_at] AS DATE)
        ORDER BY p.[start_date] DESC
    ) AS pr
    WHERE o.[project_id] IS NULL
      AND o.[order_number] LIKE 'SEED-%'
      AND o.[id] % 10 < 6;

    DECLARE @linked_orders INT = @@ROWCOUNT;

    COMMIT TRANSACTION;

    SELECT @inserted_projects AS [inserted_projects], @linked_orders AS [linked_seed_orders];
END;
