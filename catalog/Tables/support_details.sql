-- Szczegóły usług wsparcia IT.
CREATE TABLE [catalog].[support_details]
(
    [product_id]      BIGINT           NOT NULL,
    [product_kind]    VARCHAR(20)      NOT NULL CONSTRAINT [df_catalog_support_details_product_kind] DEFAULT 'support',
    [billing_period]  VARCHAR(20)      NOT NULL,  -- one_time | hourly | monthly | yearly
    [sla_level]       VARCHAR(20)      NULL,      -- basic | standard | premium
    [response_hours]  INT              NULL,
    [support_hours]   NVARCHAR(50)     NULL,      -- np. 8x5, 24x7
    CONSTRAINT [pk_catalog_support_details] PRIMARY KEY CLUSTERED ([product_id]),
    CONSTRAINT [fk_catalog_support_details_product] FOREIGN KEY ([product_id], [product_kind])
        REFERENCES [catalog].[products] ([id], [product_kind]),
    CONSTRAINT [ck_catalog_support_details_product_kind] CHECK ([product_kind] = 'support'),
    CONSTRAINT [ck_catalog_support_details_billing_period] CHECK ([billing_period] IN ('one_time', 'hourly', 'monthly', 'yearly')),
    CONSTRAINT [ck_catalog_support_details_sla_level] CHECK ([sla_level] IS NULL OR [sla_level] IN ('basic', 'standard', 'premium')),
    CONSTRAINT [ck_catalog_support_details_response_hours] CHECK ([response_hours] IS NULL OR [response_hours] > 0)
);
