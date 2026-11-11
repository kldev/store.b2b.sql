-- Klient CRM: firma albo osoba.
CREATE TABLE [crm].[clients]
(
    [id]            BIGINT         IDENTITY(1, 1) NOT NULL,
    [kind]          VARCHAR(20)    NOT NULL,
    [name]          NVARCHAR(300)  NOT NULL,
    [tax_id]        VARCHAR(20)    NULL,
    [registry_id]   VARCHAR(20)    NULL,
    [email]         NVARCHAR(254)  NULL,
    [phone]         VARCHAR(30)    NULL,
    [website]       NVARCHAR(300)  NULL,
    [street]        NVARCHAR(200)  NULL,
    [postal_code]   VARCHAR(12)    NULL,
    [city]          NVARCHAR(100)  NULL,
    [country_code]  CHAR(2)        NOT NULL CONSTRAINT [df_clients_country_code] DEFAULT ('PL'),
    [status]        VARCHAR(20)    NOT NULL CONSTRAINT [df_clients_status] DEFAULT ('lead'),
    [source]        NVARCHAR(100)  NULL,
    [owner_user_id] BIGINT         NULL,
    [notes]         NVARCHAR(MAX)  NULL,
    [created_at]    DATETIME2(3)   NOT NULL CONSTRAINT [df_clients_created_at] DEFAULT (SYSUTCDATETIME()),
    [created_by]    BIGINT         NULL,
    [updated_at]    DATETIME2(3)   NOT NULL CONSTRAINT [df_clients_updated_at] DEFAULT (SYSUTCDATETIME()),
    [updated_by]    BIGINT         NULL,
    [deleted_at]    DATETIME2(3)   NULL,
    [row_version]   ROWVERSION     NOT NULL,
    CONSTRAINT [pk_clients] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [ck_clients_kind] CHECK ([kind] IN ('person', 'company')),
    CONSTRAINT [ck_clients_name] CHECK (LEN(LTRIM(RTRIM([name]))) > 0),
    CONSTRAINT [ck_clients_email] CHECK ([email] IS NULL OR [email] LIKE N'_%@_%._%'),
    CONSTRAINT [ck_clients_country] CHECK ([country_code] LIKE '[A-Z][A-Z]'),
    CONSTRAINT [ck_clients_status] CHECK ([status] IN ('lead', 'prospect', 'active', 'inactive', 'lost'))
);
GO
CREATE NONCLUSTERED INDEX [ix_clients_name]
    ON [crm].[clients] ([name]);
GO
CREATE NONCLUSTERED INDEX [ix_clients_owner]
    ON [crm].[clients] ([owner_user_id])
    WHERE [deleted_at] IS NULL;
GO
CREATE NONCLUSTERED INDEX [ix_clients_status]
    ON [crm].[clients] ([status])
    WHERE [deleted_at] IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_clients_email]
    ON [crm].[clients] ([email])
    WHERE [email] IS NOT NULL AND [deleted_at] IS NULL;
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_clients_tax_id]
    ON [crm].[clients] ([country_code], [tax_id])
    WHERE [tax_id] IS NOT NULL AND [deleted_at] IS NULL;
