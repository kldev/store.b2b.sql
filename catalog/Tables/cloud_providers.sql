-- Dostawcy chmury (Azure, GCP, AWS).
CREATE TABLE [catalog].[cloud_providers]
(
    [code] VARCHAR(20)   NOT NULL,
    [name] NVARCHAR(100) NOT NULL,
    CONSTRAINT [pk_catalog_cloud_providers] PRIMARY KEY CLUSTERED ([code])
);
