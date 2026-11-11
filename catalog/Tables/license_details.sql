-- Szczegóły licencji na oprogramowanie.
CREATE TABLE [catalog].[license_details]
(
    [product_id]     BIGINT           NOT NULL,
    [product_kind]   VARCHAR(20)      NOT NULL CONSTRAINT [df_catalog_license_details_product_kind] DEFAULT 'license',
    [license_model]  VARCHAR(20)      NOT NULL,  -- perpetual | subscription
    [metric]         VARCHAR(20)      NOT NULL,  -- user | device | core | server
    [term_months]    INT              NULL,
    [min_quantity]   INT              NOT NULL CONSTRAINT [df_catalog_license_details_min_quantity] DEFAULT 1,
    CONSTRAINT [pk_catalog_license_details] PRIMARY KEY CLUSTERED ([product_id]),
    CONSTRAINT [fk_catalog_license_details_product] FOREIGN KEY ([product_id], [product_kind])
        REFERENCES [catalog].[products] ([id], [product_kind]),
    CONSTRAINT [ck_catalog_license_details_product_kind] CHECK ([product_kind] = 'license'),
    CONSTRAINT [ck_catalog_license_details_license_model] CHECK ([license_model] IN ('perpetual', 'subscription')),
    CONSTRAINT [ck_catalog_license_details_metric] CHECK ([metric] IN ('user', 'device', 'core', 'server')),
    -- Subskrypcja ma okres, licencja wieczysta nie.
    CONSTRAINT [ck_catalog_license_details_term] CHECK (
        ([license_model] = 'subscription' AND [term_months] > 0)
        OR ([license_model] = 'perpetual' AND [term_months] IS NULL)),
    CONSTRAINT [ck_catalog_license_details_min_quantity] CHECK ([min_quantity] > 0)
);
