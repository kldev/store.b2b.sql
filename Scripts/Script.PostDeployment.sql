/*
Dane słownikowe sklepu B2B — idempotentnie (MERGE), uruchamiane po każdej publikacji dacpac.
*/
MERGE [catalog].[product_categories] AS t
USING (VALUES
    ('server',           N'Serwery',                 'hardware'),
    ('router',           N'Routery',                 'hardware'),
    ('switch',           N'Switche',                 'hardware'),
    ('laptop',           N'Laptopy',                 'hardware'),
    ('software_license', N'Licencje oprogramowania', 'license'),
    ('it_support',       N'Wsparcie IT',             'support'),
    ('cloud_service',    N'Usługi chmurowe',         'cloud')
) AS s ([code], [name], [product_kind])
ON t.[code] = s.[code]
WHEN MATCHED AND (t.[name] <> s.[name] OR t.[product_kind] <> s.[product_kind])
    THEN UPDATE SET t.[name] = s.[name], t.[product_kind] = s.[product_kind]
WHEN NOT MATCHED BY TARGET
    THEN INSERT ([code], [name], [product_kind]) VALUES (s.[code], s.[name], s.[product_kind]);

MERGE [catalog].[manufacturers] AS t
USING (VALUES
    ('HP',        N'HP / Hewlett Packard Enterprise'),
    ('DELL',      N'Dell Technologies'),
    ('LENOVO',    N'Lenovo'),
    ('CISCO',     N'Cisco'),
    ('JUNIPER',   N'Juniper Networks'),
    ('MIKROTIK',  N'MikroTik'),
    ('MICROSOFT', N'Microsoft'),
    ('VMWARE',    N'VMware by Broadcom'),
    ('REDHAT',    N'Red Hat')
) AS s ([code], [name])
ON t.[code] = s.[code]
WHEN MATCHED AND t.[name] <> s.[name] THEN UPDATE SET t.[name] = s.[name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([code], [name]) VALUES (s.[code], s.[name]);

MERGE [catalog].[cloud_providers] AS t
USING (VALUES
    ('AZURE', N'Microsoft Azure'),
    ('GCP',   N'Google Cloud Platform'),
    ('AWS',   N'Amazon Web Services')
) AS s ([code], [name])
ON t.[code] = s.[code]
WHEN MATCHED AND t.[name] <> s.[name] THEN UPDATE SET t.[name] = s.[name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([code], [name]) VALUES (s.[code], s.[name]);

MERGE [catalog].[units] AS t
USING (VALUES
    ('pcs',     N'sztuka'),
    ('license', N'licencja'),
    ('hour',    N'godzina'),
    ('month',   N'miesiąc'),
    ('year',    N'rok'),
    ('usage',   N'wg zużycia')
) AS s ([code], [name])
ON t.[code] = s.[code]
WHEN MATCHED AND t.[name] <> s.[name] THEN UPDATE SET t.[name] = s.[name]
WHEN NOT MATCHED BY TARGET THEN INSERT ([code], [name]) VALUES (s.[code], s.[name]);
