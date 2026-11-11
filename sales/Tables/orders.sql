-- Zamówienie klienta, opcjonalnie z oferty i w ramach projektu klienta.
CREATE TABLE [sales].[orders]
(
    [id]            BIGINT           IDENTITY(1, 1) NOT NULL,
    [order_number]  VARCHAR(30)      NOT NULL,
    [client_id]     BIGINT           NOT NULL,
    [project_id]    BIGINT           NULL,
    [quote_id]      BIGINT           NULL,
    [status]        VARCHAR(20)      NOT NULL CONSTRAINT [df_sales_orders_status] DEFAULT 'new',
    [currency_code] CHAR(3)          NOT NULL CONSTRAINT [df_sales_orders_currency_code] DEFAULT 'PLN',
    [ordered_at]    DATETIME2(3)     NOT NULL CONSTRAINT [df_sales_orders_ordered_at] DEFAULT SYSUTCDATETIME(),
    [customer_po]   NVARCHAR(50)     NULL,  -- numer zamówienia po stronie klienta
    [notes]         NVARCHAR(2000)   NULL,
    [row_version]   ROWVERSION       NOT NULL,
    CONSTRAINT [pk_sales_orders] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [ux_sales_orders_order_number] UNIQUE ([order_number]),
    CONSTRAINT [fk_sales_orders_client] FOREIGN KEY ([client_id]) REFERENCES [crm].[clients] ([id]),
    CONSTRAINT [fk_sales_orders_project] FOREIGN KEY ([client_id], [project_id])
        REFERENCES [crm].[projects] ([client_id], [id]),
    -- Oferta musi być tego samego klienta.
    CONSTRAINT [fk_sales_orders_quote] FOREIGN KEY ([quote_id], [client_id])
        REFERENCES [sales].[quotes] ([id], [client_id]),
    CONSTRAINT [ck_sales_orders_status] CHECK ([status]      IN ('new', 'confirmed', 'in_fulfillment', 'completed', 'cancelled')),
    CONSTRAINT [ck_sales_orders_currency_code] CHECK ([currency_code] LIKE '[A-Z][A-Z][A-Z]')
);
GO
CREATE NONCLUSTERED INDEX [ix_sales_orders_client_id] ON [sales].[orders] ([client_id], [ordered_at] DESC);
GO
CREATE NONCLUSTERED INDEX [ix_sales_orders_project_id] ON [sales].[orders] ([client_id], [project_id]) WHERE [project_id] IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [ix_sales_orders_quote_id] ON [sales].[orders] ([quote_id]) WHERE [quote_id] IS NOT NULL;
