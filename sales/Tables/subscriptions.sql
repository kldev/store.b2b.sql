-- Aktywne usługi klienta w czasie: licencje subskrypcyjne, umowy wsparcia, usługi chmurowe.
CREATE TABLE [sales].[subscriptions]
(
    [id]               BIGINT           IDENTITY(1, 1) NOT NULL,
    [client_id]        BIGINT           NOT NULL,
    [project_id]       BIGINT           NULL,
    [product_id]       BIGINT           NOT NULL,
    [order_line_id]    BIGINT           NULL,
    [quantity]         DECIMAL(19, 4)   NOT NULL,
    [start_date]       DATE             NOT NULL,
    [end_date]         DATE             NULL,
    [auto_renew]       BIT              NOT NULL CONSTRAINT [df_sales_subscriptions_auto_renew] DEFAULT 0,
    [status]           VARCHAR(20)      NOT NULL CONSTRAINT [df_sales_subscriptions_status] DEFAULT 'active',
    [vendor_reference] NVARCHAR(100)    NULL,  -- np. id subskrypcji u dostawcy chmury lub numer kontraktu producenta
    [created_at]       DATETIME2(3)     NOT NULL CONSTRAINT [df_sales_subscriptions_created_at] DEFAULT SYSUTCDATETIME(),
    [row_version]      ROWVERSION       NOT NULL,
    CONSTRAINT [pk_sales_subscriptions] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [fk_sales_subscriptions_client] FOREIGN KEY ([client_id]) REFERENCES [crm].[clients] ([id]),
    CONSTRAINT [fk_sales_subscriptions_project] FOREIGN KEY ([client_id], [project_id])
        REFERENCES [crm].[projects] ([client_id], [id]),
    CONSTRAINT [fk_sales_subscriptions_product] FOREIGN KEY ([product_id]) REFERENCES [catalog].[products] ([id]),
    CONSTRAINT [fk_sales_subscriptions_order_line] FOREIGN KEY ([order_line_id]) REFERENCES [sales].[order_lines] ([id]),
    CONSTRAINT [ck_sales_subscriptions_quantity] CHECK ([quantity] > 0),
    CONSTRAINT [ck_sales_subscriptions_dates] CHECK ([end_date] IS NULL OR [end_date] >= [start_date]),
    CONSTRAINT [ck_sales_subscriptions_status] CHECK ([status]      IN ('active', 'suspended', 'cancelled', 'expired'))
);
GO
CREATE NONCLUSTERED INDEX [ix_sales_subscriptions_client_id] ON [sales].[subscriptions] ([client_id], [status]     , [end_date]);
GO
CREATE NONCLUSTERED INDEX [ix_sales_subscriptions_project_id] ON [sales].[subscriptions] ([client_id], [project_id]) WHERE [project_id] IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [ix_sales_subscriptions_product_id] ON [sales].[subscriptions] ([product_id]);
GO
CREATE NONCLUSTERED INDEX [ix_sales_subscriptions_order_line_id] ON [sales].[subscriptions] ([order_line_id]) WHERE [order_line_id] IS NOT NULL;
