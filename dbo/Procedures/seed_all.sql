-- Pełny seed bazy w kolejności zależności — po nim każda tabela ma dane:
--   catalog.seed_products        katalog (idempotentny, zawsze)
--   crm.seed_clients             klienci (tylko gdy tabela pusta)
--   crm.seed_projects            projekty klientów + dopięcie istniejących zamówień SEED-* do projektów
--   sales.seed_quotes            oferty z pozycjami
--   sales.seed_orders_from_quotes zamówienia z zaakceptowanych ofert (quote → order)
--   sales.seed_orders            zamówienia bez oferty
--   sales.seed_fulfillment       dostarczone egzemplarze sprzętu i subskrypcje
-- Każde uruchomienie dokłada dane (poza katalogiem i klientami). Każdy krok ma własną transakcję.
--
--   EXEC dbo.seed_all;
--   EXEC dbo.seed_all @weeks = 52, @orders_per_week = 40, @quotes_per_week = 25, @projects = 1000;
CREATE PROCEDURE [dbo].[seed_all]
    @weeks           INT = 26,
    @orders_per_week INT = 25,
    @quotes_per_week INT = 15,
    @projects        INT = 400,
    @clients         INT = 5000   -- używane tylko, gdy crm.clients jest pusta
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC [catalog].[seed_products];

    IF NOT EXISTS (SELECT 1 FROM [crm].[clients] WHERE [deleted_at] IS NULL)
        EXEC [crm].[seed_clients] @count = @clients;

    EXEC [crm].[seed_projects] @count = @projects;
    EXEC [sales].[seed_quotes] @weeks = @weeks, @quotes_per_week = @quotes_per_week;
    EXEC [sales].[seed_orders_from_quotes];
    EXEC [sales].[seed_orders] @weeks = @weeks, @orders_per_week = @orders_per_week;
    EXEC [sales].[seed_fulfillment];

    -- Podsumowanie: liczba wierszy w każdej tabeli po seedzie
    SELECT [table_name], [row_count]
    FROM (VALUES
        ('catalog.product_categories', (SELECT COUNT_BIG(*) FROM [catalog].[product_categories])),
        ('catalog.manufacturers',      (SELECT COUNT_BIG(*) FROM [catalog].[manufacturers])),
        ('catalog.cloud_providers',    (SELECT COUNT_BIG(*) FROM [catalog].[cloud_providers])),
        ('catalog.units',              (SELECT COUNT_BIG(*) FROM [catalog].[units])),
        ('catalog.products',           (SELECT COUNT_BIG(*) FROM [catalog].[products])),
        ('catalog.hardware_details',   (SELECT COUNT_BIG(*) FROM [catalog].[hardware_details])),
        ('catalog.license_details',    (SELECT COUNT_BIG(*) FROM [catalog].[license_details])),
        ('catalog.support_details',    (SELECT COUNT_BIG(*) FROM [catalog].[support_details])),
        ('catalog.cloud_details',      (SELECT COUNT_BIG(*) FROM [catalog].[cloud_details])),
        ('crm.clients',                (SELECT COUNT_BIG(*) FROM [crm].[clients])),
        ('crm.projects',               (SELECT COUNT_BIG(*) FROM [crm].[projects])),
        ('sales.quotes',               (SELECT COUNT_BIG(*) FROM [sales].[quotes])),
        ('sales.quote_lines',          (SELECT COUNT_BIG(*) FROM [sales].[quote_lines])),
        ('sales.orders',               (SELECT COUNT_BIG(*) FROM [sales].[orders])),
        ('sales.order_lines',          (SELECT COUNT_BIG(*) FROM [sales].[order_lines])),
        ('sales.delivered_devices',    (SELECT COUNT_BIG(*) FROM [sales].[delivered_devices])),
        ('sales.subscriptions',        (SELECT COUNT_BIG(*) FROM [sales].[subscriptions]))
    ) AS t ([table_name], [row_count])
    ORDER BY [table_name];
END;
