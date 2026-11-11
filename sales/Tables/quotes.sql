-- Oferta dla klienta, opcjonalnie w ramach jego projektu.
CREATE TABLE [sales].[quotes]
(
    [id]            BIGINT           IDENTITY(1, 1) NOT NULL,
    [quote_number]  VARCHAR(30)      NOT NULL,
    [client_id]     BIGINT           NOT NULL,
    [project_id]    BIGINT           NULL,
    [status]        VARCHAR(20)      NOT NULL CONSTRAINT [df_sales_quotes_status] DEFAULT 'draft',
    [currency_code] CHAR(3)          NOT NULL CONSTRAINT [df_sales_quotes_currency_code] DEFAULT 'PLN',
    [valid_until]   DATE             NULL,
    [notes]         NVARCHAR(2000)   NULL,
    [created_at]    DATETIME2(3)     NOT NULL CONSTRAINT [df_sales_quotes_created_at] DEFAULT SYSUTCDATETIME(),
    [row_version]   ROWVERSION       NOT NULL,
    CONSTRAINT [pk_sales_quotes] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [ux_sales_quotes_quote_number] UNIQUE ([quote_number]),
    CONSTRAINT [ux_sales_quotes_id_client] UNIQUE ([id], [client_id]),
    CONSTRAINT [fk_sales_quotes_client] FOREIGN KEY ([client_id]) REFERENCES [crm].[clients] ([id]),
    CONSTRAINT [fk_sales_quotes_project] FOREIGN KEY ([client_id], [project_id])
        REFERENCES [crm].[projects] ([client_id], [id]),
    CONSTRAINT [ck_sales_quotes_status] CHECK ([status]      IN ('draft', 'sent', 'accepted', 'rejected', 'expired')),
    CONSTRAINT [ck_sales_quotes_currency_code] CHECK ([currency_code] LIKE '[A-Z][A-Z][A-Z]')
);
GO
CREATE NONCLUSTERED INDEX [ix_sales_quotes_client_id] ON [sales].[quotes] ([client_id], [created_at] DESC);
GO
CREATE NONCLUSTERED INDEX [ix_sales_quotes_project_id] ON [sales].[quotes] ([client_id], [project_id]) WHERE [project_id] IS NOT NULL;
