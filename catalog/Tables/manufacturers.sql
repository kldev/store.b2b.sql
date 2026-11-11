-- Producenci sprzętu i oprogramowania (HP, Dell, Cisco, Microsoft…).
CREATE TABLE [catalog].[manufacturers]
(
    [code]      VARCHAR(30)   NOT NULL,
    [name]      NVARCHAR(100) NOT NULL,
    [is_active] BIT           NOT NULL CONSTRAINT [df_catalog_manufacturers_is_active] DEFAULT 1,
    CONSTRAINT [pk_catalog_manufacturers] PRIMARY KEY CLUSTERED ([code])
);
