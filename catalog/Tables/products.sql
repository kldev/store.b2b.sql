-- Pozycja katalogu: sprzęt, licencja, usługa wsparcia albo usługa chmurowa.
CREATE TABLE [catalog].[products]
(
    [id]                       BIGINT           IDENTITY(1, 1) NOT NULL,
    [sku]                      VARCHAR(50)      NOT NULL,
    [name]                     NVARCHAR(200)    NOT NULL,
    [description]              NVARCHAR(2000)   NULL,
    [category_code]            VARCHAR(30)      NOT NULL,
    [product_kind]             VARCHAR(20)      NOT NULL,
    [manufacturer_code]        VARCHAR(30)      NULL,
    [manufacturer_part_number] VARCHAR(50)      NULL,
    [cloud_provider_code]      VARCHAR(20)      NULL,
    [unit_code]                VARCHAR(20)      NOT NULL,
    [list_price]               DECIMAL(19, 4)   NOT NULL,
    [currency_code]            CHAR(3)          NOT NULL CONSTRAINT [df_catalog_products_currency_code] DEFAULT 'PLN',
    [is_active]                BIT              NOT NULL CONSTRAINT [df_catalog_products_is_active] DEFAULT 1,
    [created_at]               DATETIME2(3)     NOT NULL CONSTRAINT [df_catalog_products_created_at] DEFAULT SYSUTCDATETIME(),
    [row_version]              ROWVERSION       NOT NULL,
    CONSTRAINT [pk_catalog_products] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [ux_catalog_products_sku] UNIQUE ([sku]),
    -- Cel złożonych FK z tabel szczegółów: szczegóły pasują do rodzaju produktu.
    CONSTRAINT [ux_catalog_products_id_kind] UNIQUE ([id], [product_kind]),
    CONSTRAINT [fk_catalog_products_category] FOREIGN KEY ([category_code], [product_kind])
        REFERENCES [catalog].[product_categories] ([code], [product_kind]),
    CONSTRAINT [fk_catalog_products_manufacturer] FOREIGN KEY ([manufacturer_code])
        REFERENCES [catalog].[manufacturers] ([code]),
    CONSTRAINT [fk_catalog_products_cloud_provider] FOREIGN KEY ([cloud_provider_code])
        REFERENCES [catalog].[cloud_providers] ([code]),
    CONSTRAINT [fk_catalog_products_unit] FOREIGN KEY ([unit_code]) REFERENCES [catalog].[units] ([code]),
    CONSTRAINT [ck_catalog_products_list_price] CHECK ([list_price] >= 0),
    CONSTRAINT [ck_catalog_products_currency_code] CHECK ([currency_code] LIKE '[A-Z][A-Z][A-Z]'),
    -- Sprzęt i licencje mają producenta; chmura ma dostawcę chmury i tylko ona.
    CONSTRAINT [ck_catalog_products_manufacturer] CHECK ([product_kind] NOT IN ('hardware', 'license') OR [manufacturer_code] IS NOT NULL),
    CONSTRAINT [ck_catalog_products_cloud_provider] CHECK (
        ([product_kind] = 'cloud' AND [cloud_provider_code] IS NOT NULL)
        OR ([product_kind] <> 'cloud' AND [cloud_provider_code] IS NULL))
);
GO
CREATE NONCLUSTERED INDEX [ix_catalog_products_category_code] ON [catalog].[products] ([category_code], [product_kind]);
GO
CREATE NONCLUSTERED INDEX [ix_catalog_products_manufacturer_code] ON [catalog].[products] ([manufacturer_code]) WHERE [manufacturer_code] IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [ix_catalog_products_cloud_provider_code] ON [catalog].[products] ([cloud_provider_code]) WHERE [cloud_provider_code] IS NOT NULL;
GO
CREATE NONCLUSTERED INDEX [ix_catalog_products_unit_code] ON [catalog].[products] ([unit_code]);
GO
CREATE UNIQUE NONCLUSTERED INDEX [ux_catalog_products_manufacturer_part_number]
    ON [catalog].[products] ([manufacturer_code], [manufacturer_part_number])
    WHERE [manufacturer_part_number] IS NOT NULL;
