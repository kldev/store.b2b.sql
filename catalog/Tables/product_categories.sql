-- Kategorie oferty; product_kind określa, która tabela szczegółów obowiązuje produkt.
CREATE TABLE [catalog].[product_categories]
(
    [code]         VARCHAR(30)   NOT NULL,
    [name]         NVARCHAR(100) NOT NULL,
    [product_kind] VARCHAR(20)   NOT NULL,
    CONSTRAINT [pk_catalog_product_categories] PRIMARY KEY CLUSTERED ([code]),
    CONSTRAINT [ux_catalog_product_categories_code_kind] UNIQUE ([code], [product_kind]),
    CONSTRAINT [ck_catalog_product_categories_product_kind] CHECK ([product_kind] IN ('hardware', 'license', 'support', 'cloud'))
);
