-- Szczegóły sprzętu: serwery, routery, switche, laptopy.
CREATE TABLE [catalog].[hardware_details]
(
    [product_id]      BIGINT           NOT NULL,
    [product_kind]    VARCHAR(20)      NOT NULL CONSTRAINT [df_catalog_hardware_details_product_kind] DEFAULT 'hardware',
    [form_factor]     NVARCHAR(50)     NULL,  -- np. rack 1U, tower, notebook 14"
    [cpu]             NVARCHAR(100)    NULL,
    [ram_gb]          INT              NULL,
    [storage]         NVARCHAR(200)    NULL,
    [port_count]      INT              NULL,  -- routery i switche
    [warranty_months] INT              NOT NULL CONSTRAINT [df_catalog_hardware_details_warranty_months] DEFAULT 12,
    CONSTRAINT [pk_catalog_hardware_details] PRIMARY KEY CLUSTERED ([product_id]),
    CONSTRAINT [fk_catalog_hardware_details_product] FOREIGN KEY ([product_id], [product_kind])
        REFERENCES [catalog].[products] ([id], [product_kind]),
    CONSTRAINT [ck_catalog_hardware_details_product_kind] CHECK ([product_kind] = 'hardware'),
    CONSTRAINT [ck_catalog_hardware_details_ram_gb] CHECK ([ram_gb] IS NULL OR [ram_gb] > 0),
    CONSTRAINT [ck_catalog_hardware_details_port_count] CHECK ([port_count] IS NULL OR [port_count] > 0),
    CONSTRAINT [ck_catalog_hardware_details_warranty_months] CHECK ([warranty_months] >= 0)
);
