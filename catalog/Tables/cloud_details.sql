-- Szczegóły usług chmurowych (Azure, GCP, AWS); dostawca jest w catalog.products.
CREATE TABLE [catalog].[cloud_details]
(
    [product_id]     BIGINT           NOT NULL,
    [product_kind]   VARCHAR(20)      NOT NULL CONSTRAINT [df_catalog_cloud_details_product_kind] DEFAULT 'cloud',
    [service_type]   VARCHAR(20)      NOT NULL,  -- iaas | paas | saas | managed
    [billing_model]  VARCHAR(20)      NOT NULL,  -- monthly | yearly | usage | reserved
    [term_months]    INT              NULL,      -- dla rezerwacji / zobowiązań
    [region]         VARCHAR(50)      NULL,
    CONSTRAINT [pk_catalog_cloud_details] PRIMARY KEY CLUSTERED ([product_id]),
    CONSTRAINT [fk_catalog_cloud_details_product] FOREIGN KEY ([product_id], [product_kind])
        REFERENCES [catalog].[products] ([id], [product_kind]),
    CONSTRAINT [ck_catalog_cloud_details_product_kind] CHECK ([product_kind] = 'cloud'),
    CONSTRAINT [ck_catalog_cloud_details_service_type] CHECK ([service_type] IN ('iaas', 'paas', 'saas', 'managed')),
    CONSTRAINT [ck_catalog_cloud_details_billing_model] CHECK ([billing_model] IN ('monthly', 'yearly', 'usage', 'reserved')),
    CONSTRAINT [ck_catalog_cloud_details_term] CHECK ([billing_model] <> 'reserved' OR [term_months] > 0)
);
