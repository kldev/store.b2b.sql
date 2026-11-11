-- Lista zamówień (ekran "Zamówienia" i zakładka zamówień klienta / projektu).
-- Jeden wiersz = jedno zamówienie z klientem, projektem, ofertą źródłową i sumami z pozycji.
-- Kwoty netto liczone z cen zapisanych w pozycjach w chwili sprzedaży (nie z katalogu), w walucie zamówienia.
-- Filtry z listy: client_id, project_id, status, ordered_at od–do (indeksy ix_sales_orders_client_id / _project_id).
CREATE VIEW [app].[orders]
AS
SELECT
    o.[id],
    o.[order_number],
    o.[status],
    o.[ordered_at],
    o.[customer_po],
    o.[currency_code],
    o.[client_id],
    c.[name]                                   AS [client_name],
    c.[tax_id]                                 AS [client_tax_id],
    o.[project_id],
    p.[name]                                   AS [project_name],
    p.[status]                                 AS [project_status],
    o.[quote_id],
    q.[quote_number],
    ISNULL(t.[line_count], 0)                  AS [line_count],
    ISNULL(t.[hardware_line_count], 0)         AS [hardware_line_count],
    ISNULL(t.[service_line_count], 0)          AS [service_line_count],
    CAST(ISNULL(t.[gross_list_amount], 0) AS DECIMAL(19, 4)) AS [amount_before_discount],
    CAST(ISNULL(t.[net_amount], 0) AS DECIMAL(19, 4))        AS [net_amount],
    o.[row_version]
FROM [sales].[orders] AS o
JOIN [crm].[clients] AS c
    ON c.[id] = o.[client_id]
LEFT JOIN [crm].[projects] AS p
    ON p.[client_id] = o.[client_id]
   AND p.[id] = o.[project_id]
LEFT JOIN [sales].[quotes] AS q
    ON q.[id] = o.[quote_id]
OUTER APPLY (
    SELECT
        COUNT_BIG(*)                                                            AS [line_count],
        SUM(CASE WHEN pr.[product_kind] = 'hardware' THEN 1 ELSE 0 END)         AS [hardware_line_count],
        SUM(CASE WHEN pr.[product_kind] IN ('license', 'support', 'cloud') THEN 1 ELSE 0 END) AS [service_line_count],
        SUM(ol.[quantity] * ol.[unit_price])                                    AS [gross_list_amount],
        SUM(ol.[quantity] * ol.[unit_price] * (100 - ol.[discount_percent]) / 100) AS [net_amount]
    FROM [sales].[order_lines] AS ol
    JOIN [catalog].[products] AS pr
        ON pr.[id] = ol.[product_id]
    WHERE ol.[order_id] = o.[id]
) AS t;
