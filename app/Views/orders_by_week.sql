-- Liczba zamówień tygodniowo (wykres / tabela "Zamówienia w tygodniach" na pulpicie sprzedaży).
-- Jeden wiersz = jeden tydzień ISO (poniedziałek–niedziela) z co najmniej jednym zamówieniem;
-- tygodnie bez zamówień uzupełnia front (albo przyszła funkcja z zakresem dat).
-- Granice tygodni liczone na ordered_at w UTC. Filtr z API: week_start od–do, iso_year.
-- Kwot tu nie ma celowo: zamówienia mogą być w różnych walutach, a sumy są w app.orders.
CREATE VIEW [app].[orders_by_week]
AS
SELECT
    w.[week_start],
    DATEADD(DAY, 6, w.[week_start])                                      AS [week_end],
    -- Rok ISO = rok, do którego należy czwartek tego tygodnia (tydzień 1 może zaczynać się w grudniu).
    YEAR(DATEADD(DAY, 3, w.[week_start]))                                AS [iso_year],
    DATEPART(ISO_WEEK, w.[week_start])                                   AS [iso_week],
    COUNT_BIG(*)                                                         AS [order_count],
    COUNT_BIG(DISTINCT o.[client_id])                                    AS [client_count],
    SUM(CASE WHEN o.[project_id] IS NOT NULL THEN 1 ELSE 0 END)          AS [project_order_count],
    SUM(CASE WHEN o.[status] = 'new'            THEN 1 ELSE 0 END)       AS [new_count],
    SUM(CASE WHEN o.[status] = 'confirmed'      THEN 1 ELSE 0 END)       AS [confirmed_count],
    SUM(CASE WHEN o.[status] = 'in_fulfillment' THEN 1 ELSE 0 END)       AS [in_fulfillment_count],
    SUM(CASE WHEN o.[status] = 'completed'      THEN 1 ELSE 0 END)       AS [completed_count],
    SUM(CASE WHEN o.[status] = 'cancelled'      THEN 1 ELSE 0 END)       AS [cancelled_count]
FROM [sales].[orders] AS o
-- Poniedziałek tygodnia: 1900-01-01 był poniedziałkiem, więc reszta z dzielenia przez 7 to dzień tygodnia (0 = pn).
CROSS APPLY (
    SELECT DATEADD(DAY, -(DATEDIFF(DAY, CAST('19000101' AS DATE), CAST(o.[ordered_at] AS DATE)) % 7),
                   CAST(o.[ordered_at] AS DATE)) AS [week_start]
) AS w
GROUP BY w.[week_start];
