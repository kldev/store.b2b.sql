-- Wstawia albo aktualizuje przykładowy katalog sklepu B2B: serwery, routery, switche, laptopy,
-- licencje, usługi wsparcia IT i usługi chmurowe. Idempotentna: klucz to SKU, kolejne uruchomienie
-- poprawia istniejące pozycje zamiast je dublować. Ceny są przykładowe (netto, PLN).
-- Wymaga słowników z Scripts/Script.PostDeployment.sql (kategorie, producenci, chmury, jednostki).
CREATE PROCEDURE [catalog].[seed_products]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ---------------------------------------------------------------------------------------------
    -- 1. Produkty (część wspólna)
    ---------------------------------------------------------------------------------------------
    DECLARE @products TABLE
    (
        [sku]                 VARCHAR(50)    NOT NULL PRIMARY KEY,
        [name]                NVARCHAR(200)  NOT NULL,
        [category_code]       VARCHAR(30)    NOT NULL,
        [product_kind]        VARCHAR(20)    NOT NULL,
        [manufacturer_code]   VARCHAR(30)    NULL,
        [cloud_provider_code] VARCHAR(20)    NULL,
        [unit_code]           VARCHAR(20)    NOT NULL,
        [list_price]          DECIMAL(19, 4) NOT NULL
    );

    INSERT INTO @products ([sku], [name], [category_code], [product_kind], [manufacturer_code], [cloud_provider_code], [unit_code], [list_price])
    VALUES
        -- Serwery
        ('SRV-HPE-DL360-G11',  N'HPE ProLiant DL360 Gen11',            'server', 'hardware', 'HP',     NULL, 'pcs', 28900.00),
        ('SRV-HPE-DL380-G11',  N'HPE ProLiant DL380 Gen11',            'server', 'hardware', 'HP',     NULL, 'pcs', 34500.00),
        ('SRV-HPE-ML30-G11',   N'HPE ProLiant ML30 Gen11',             'server', 'hardware', 'HP',     NULL, 'pcs',  8900.00),
        ('SRV-DELL-R660',      N'Dell PowerEdge R660',                 'server', 'hardware', 'DELL',   NULL, 'pcs', 27500.00),
        ('SRV-DELL-R760',      N'Dell PowerEdge R760',                 'server', 'hardware', 'DELL',   NULL, 'pcs', 33900.00),
        ('SRV-DELL-T160',      N'Dell PowerEdge T160',                 'server', 'hardware', 'DELL',   NULL, 'pcs',  7600.00),
        ('SRV-LEN-SR650-V3',   N'Lenovo ThinkSystem SR650 V3',         'server', 'hardware', 'LENOVO', NULL, 'pcs', 31200.00),
        -- Routery
        ('RTR-CSC-ISR1100-4G', N'Cisco ISR 1100 4G',                   'router', 'hardware', 'CISCO',    NULL, 'pcs',  3900.00),
        ('RTR-CSC-C8200',      N'Cisco Catalyst 8200 Edge',            'router', 'hardware', 'CISCO',    NULL, 'pcs', 12400.00),
        ('RTR-MT-CCR2004',     N'MikroTik CCR2004-16G-2S+',            'router', 'hardware', 'MIKROTIK', NULL, 'pcs',  2300.00),
        ('RTR-JNP-SRX300',     N'Juniper SRX300',                      'router', 'hardware', 'JUNIPER',  NULL, 'pcs',  4100.00),
        -- Switche
        ('SW-CSC-C9200-24P',   N'Cisco Catalyst 9200 24 porty PoE+',   'switch', 'hardware', 'CISCO',    NULL, 'pcs',  9800.00),
        ('SW-CSC-C9300-48P',   N'Cisco Catalyst 9300 48 portów PoE+',  'switch', 'hardware', 'CISCO',    NULL, 'pcs', 24500.00),
        ('SW-HPE-AR6100-24G',  N'HPE Aruba 6100 24G 4SFP+',            'switch', 'hardware', 'HP',       NULL, 'pcs',  4600.00),
        ('SW-DELL-N3248TE',    N'Dell PowerSwitch N3248TE-ON',         'switch', 'hardware', 'DELL',     NULL, 'pcs', 11900.00),
        ('SW-MT-CRS326-24G',   N'MikroTik CRS326-24G-2S+',             'switch', 'hardware', 'MIKROTIK', NULL, 'pcs',   950.00),
        -- Laptopy
        ('NB-HP-EB840-G11',    N'HP EliteBook 840 G11',                'laptop', 'hardware', 'HP',     NULL, 'pcs',  6400.00),
        ('NB-HP-PB450-G10',    N'HP ProBook 450 G10',                  'laptop', 'hardware', 'HP',     NULL, 'pcs',  3900.00),
        ('NB-DELL-LAT5450',    N'Dell Latitude 5450',                  'laptop', 'hardware', 'DELL',   NULL, 'pcs',  5200.00),
        ('NB-DELL-PREC3591',   N'Dell Precision 3591',                 'laptop', 'hardware', 'DELL',   NULL, 'pcs',  8700.00),
        ('NB-LEN-T14-G5',      N'Lenovo ThinkPad T14 Gen 5',           'laptop', 'hardware', 'LENOVO', NULL, 'pcs',  5600.00),
        ('NB-LEN-X1C-G12',     N'Lenovo ThinkPad X1 Carbon Gen 12',    'laptop', 'hardware', 'LENOVO', NULL, 'pcs',  8900.00),
        -- Licencje
        ('LIC-MS-M365-BS',     N'Microsoft 365 Business Standard (rok)',        'software_license', 'license', 'MICROSOFT', NULL, 'license',   620.00),
        ('LIC-MS-M365-E3',     N'Microsoft 365 E3 (rok)',                        'software_license', 'license', 'MICROSOFT', NULL, 'license',  1750.00),
        ('LIC-MS-WS25-STD16',  N'Windows Server 2025 Standard 16 rdzeni',        'software_license', 'license', 'MICROSOFT', NULL, 'license',  4300.00),
        ('LIC-MS-WS25-UCAL',   N'Windows Server 2025 CAL użytkownika',           'software_license', 'license', 'MICROSOFT', NULL, 'license',   190.00),
        ('LIC-MS-SQL22-STD2C', N'SQL Server 2022 Standard (2 rdzenie)',          'software_license', 'license', 'MICROSOFT', NULL, 'license', 15500.00),
        ('LIC-VMW-VVF-CORE',   N'VMware vSphere Foundation (rdzeń, rok)',        'software_license', 'license', 'VMWARE',    NULL, 'license',   780.00),
        ('LIC-RH-RHEL-STD',    N'Red Hat Enterprise Linux Server Standard (rok)', 'software_license', 'license', 'REDHAT',    NULL, 'license',  3600.00),
        -- Usługi wsparcia IT
        ('SUP-HELPDESK-8X5',   N'Helpdesk 8x5 (na użytkownika, miesiąc)',  'it_support', 'support', NULL, NULL, 'month',   49.00),
        ('SUP-ONSITE-HOUR',    N'Technik na miejscu (godzina)',            'it_support', 'support', NULL, NULL, 'hour',   180.00),
        ('SUP-SRV-MON-24X7',   N'Monitoring serwerów 24x7 (serwer, miesiąc)', 'it_support', 'support', NULL, NULL, 'month', 290.00),
        ('SUP-NET-AUDIT',      N'Audyt sieci (jednorazowo)',               'it_support', 'support', NULL, NULL, 'pcs',   4500.00),
        ('SUP-SLA-PREM-4H',    N'Kontrakt serwisowy Premium 24x7, reakcja 4h (rok)', 'it_support', 'support', NULL, NULL, 'year', 6900.00),
        -- Usługi chmurowe
        ('CLD-AZ-CONSUMPTION', N'Microsoft Azure — rozliczenie wg zużycia',      'cloud_service', 'cloud', NULL, 'AZURE', 'usage',    0.00),
        ('CLD-AZ-VM-D4SV5-RI1',N'Azure VM D4s v5 — rezerwacja 1 rok',            'cloud_service', 'cloud', NULL, 'AZURE', 'month',  520.00),
        ('CLD-AZ-MANAGED',     N'Zarządzanie subskrypcją Azure (miesiąc)',       'cloud_service', 'cloud', NULL, 'AZURE', 'month', 1200.00),
        ('CLD-AWS-CONSUMPTION',N'Amazon Web Services — rozliczenie wg zużycia',  'cloud_service', 'cloud', NULL, 'AWS',   'usage',    0.00),
        ('CLD-AWS-EC2-RI1',    N'AWS EC2 m7i.xlarge — rezerwacja 1 rok',         'cloud_service', 'cloud', NULL, 'AWS',   'month',  560.00),
        ('CLD-GCP-CONSUMPTION',N'Google Cloud — rozliczenie wg zużycia',         'cloud_service', 'cloud', NULL, 'GCP',   'usage',    0.00),
        ('CLD-GCP-GWS-BS',     N'Google Workspace Business Standard (miesiąc)',  'cloud_service', 'cloud', NULL, 'GCP',   'month',   55.00);

    ---------------------------------------------------------------------------------------------
    -- 2. Szczegóły per rodzaj (klucz: SKU z listy wyżej)
    ---------------------------------------------------------------------------------------------
    DECLARE @hardware TABLE
    (
        [sku] VARCHAR(50) NOT NULL PRIMARY KEY, [form_factor] NVARCHAR(50) NULL, [cpu] NVARCHAR(100) NULL,
        [ram_gb] INT NULL, [storage] NVARCHAR(200) NULL, [port_count] INT NULL, [warranty_months] INT NOT NULL
    );
    INSERT INTO @hardware ([sku], [form_factor], [cpu], [ram_gb], [storage], [port_count], [warranty_months])
    VALUES
        ('SRV-HPE-DL360-G11',  N'rack 1U', N'Intel Xeon Silver 4410Y',  64, N'2x 960 GB SSD',      NULL, 36),
        ('SRV-HPE-DL380-G11',  N'rack 2U', N'2x Intel Xeon Silver 4416+', 128, N'4x 1.92 TB SSD',  NULL, 36),
        ('SRV-HPE-ML30-G11',   N'tower',   N'Intel Xeon E-2434',        32, N'2x 1 TB HDD',        NULL, 36),
        ('SRV-DELL-R660',      N'rack 1U', N'Intel Xeon Silver 4410Y',  64, N'2x 960 GB SSD',      NULL, 36),
        ('SRV-DELL-R760',      N'rack 2U', N'2x Intel Xeon Silver 4416+', 128, N'4x 1.92 TB SSD',  NULL, 36),
        ('SRV-DELL-T160',      N'tower',   N'Intel Xeon E-2414',        16, N'2x 2 TB HDD',        NULL, 36),
        ('SRV-LEN-SR650-V3',   N'rack 2U', N'2x Intel Xeon Silver 4410Y', 128, N'4x 1.92 TB SSD',  NULL, 36),
        ('RTR-CSC-ISR1100-4G', N'desktop', NULL, NULL, NULL,  4, 12),
        ('RTR-CSC-C8200',      N'rack 1U', NULL, NULL, NULL,  8, 12),
        ('RTR-MT-CCR2004',     N'rack 1U', NULL, NULL, NULL, 18, 12),
        ('RTR-JNP-SRX300',     N'desktop', NULL, NULL, NULL,  8, 12),
        ('SW-CSC-C9200-24P',   N'rack 1U', NULL, NULL, NULL, 28, 60),
        ('SW-CSC-C9300-48P',   N'rack 1U', NULL, NULL, NULL, 52, 60),
        ('SW-HPE-AR6100-24G',  N'rack 1U', NULL, NULL, NULL, 28, 60),
        ('SW-DELL-N3248TE',    N'rack 1U', NULL, NULL, NULL, 54, 36),
        ('SW-MT-CRS326-24G',   N'rack 1U', NULL, NULL, NULL, 26, 12),
        ('NB-HP-EB840-G11',    N'notebook 14"', N'Intel Core Ultra 5 125U', 16, N'512 GB SSD', NULL, 36),
        ('NB-HP-PB450-G10',    N'notebook 15.6"', N'Intel Core i5-1335U',   16, N'512 GB SSD', NULL, 12),
        ('NB-DELL-LAT5450',    N'notebook 14"', N'Intel Core Ultra 5 135U', 16, N'512 GB SSD', NULL, 36),
        ('NB-DELL-PREC3591',   N'notebook 15.6"', N'Intel Core Ultra 7 155H', 32, N'1 TB SSD', NULL, 36),
        ('NB-LEN-T14-G5',      N'notebook 14"', N'Intel Core Ultra 5 125U', 16, N'512 GB SSD', NULL, 36),
        ('NB-LEN-X1C-G12',     N'notebook 14"', N'Intel Core Ultra 7 155U', 32, N'1 TB SSD',   NULL, 36);

    DECLARE @license TABLE
    (
        [sku] VARCHAR(50) NOT NULL PRIMARY KEY, [license_model] VARCHAR(20) NOT NULL, [metric] VARCHAR(20) NOT NULL,
        [term_months] INT NULL, [min_quantity] INT NOT NULL
    );
    INSERT INTO @license ([sku], [license_model], [metric], [term_months], [min_quantity])
    VALUES
        ('LIC-MS-M365-BS',     'subscription', 'user',   12, 1),
        ('LIC-MS-M365-E3',     'subscription', 'user',   12, 1),
        ('LIC-MS-WS25-STD16',  'perpetual',    'core',   NULL, 1),
        ('LIC-MS-WS25-UCAL',   'perpetual',    'user',   NULL, 1),
        ('LIC-MS-SQL22-STD2C', 'perpetual',    'core',   NULL, 2),
        ('LIC-VMW-VVF-CORE',   'subscription', 'core',   12, 16),
        ('LIC-RH-RHEL-STD',    'subscription', 'server', 12, 1);

    DECLARE @support TABLE
    (
        [sku] VARCHAR(50) NOT NULL PRIMARY KEY, [billing_period] VARCHAR(20) NOT NULL, [sla_level] VARCHAR(20) NULL,
        [response_hours] INT NULL, [support_hours] NVARCHAR(50) NULL
    );
    INSERT INTO @support ([sku], [billing_period], [sla_level], [response_hours], [support_hours])
    VALUES
        ('SUP-HELPDESK-8X5', 'monthly',  'standard', 8,    N'8x5'),
        ('SUP-ONSITE-HOUR',  'hourly',   'basic',    24,   N'8x5'),
        ('SUP-SRV-MON-24X7', 'monthly',  'premium',  1,    N'24x7'),
        ('SUP-NET-AUDIT',    'one_time', NULL,       NULL, NULL),
        ('SUP-SLA-PREM-4H',  'yearly',   'premium',  4,    N'24x7');

    DECLARE @cloud TABLE
    (
        [sku] VARCHAR(50) NOT NULL PRIMARY KEY, [service_type] VARCHAR(20) NOT NULL, [billing_model] VARCHAR(20) NOT NULL,
        [term_months] INT NULL, [region] VARCHAR(50) NULL
    );
    INSERT INTO @cloud ([sku], [service_type], [billing_model], [term_months], [region])
    VALUES
        ('CLD-AZ-CONSUMPTION',  'iaas',    'usage',    NULL, NULL),
        ('CLD-AZ-VM-D4SV5-RI1', 'iaas',    'reserved', 12,   'polandcentral'),
        ('CLD-AZ-MANAGED',      'managed', 'monthly',  NULL, NULL),
        ('CLD-AWS-CONSUMPTION', 'iaas',    'usage',    NULL, NULL),
        ('CLD-AWS-EC2-RI1',     'iaas',    'reserved', 12,   'eu-central-2'),
        ('CLD-GCP-CONSUMPTION', 'iaas',    'usage',    NULL, NULL),
        ('CLD-GCP-GWS-BS',      'saas',    'monthly',  NULL, NULL);

    ---------------------------------------------------------------------------------------------
    -- 3. Kontrola słowników — bez nich FK i tak by nie przeszły, ale z mniej czytelnym błędem
    ---------------------------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM @products s
               WHERE NOT EXISTS (SELECT 1 FROM [catalog].[product_categories] c
                                 WHERE c.[code] = s.[category_code] AND c.[product_kind] = s.[product_kind])
                  OR NOT EXISTS (SELECT 1 FROM [catalog].[units] u WHERE u.[code] = s.[unit_code])
                  OR (s.[manufacturer_code] IS NOT NULL
                      AND NOT EXISTS (SELECT 1 FROM [catalog].[manufacturers] m WHERE m.[code] = s.[manufacturer_code]))
                  OR (s.[cloud_provider_code] IS NOT NULL
                      AND NOT EXISTS (SELECT 1 FROM [catalog].[cloud_providers] cp WHERE cp.[code] = s.[cloud_provider_code])))
        THROW 50101, N'Brak słowników katalogu (kategorie, jednostki, producenci, chmury). Opublikuj projekt z Script.PostDeployment.sql.', 1;

    BEGIN TRANSACTION;

    ---------------------------------------------------------------------------------------------
    -- 4. Produkty: MERGE po SKU (aktualizuj tylko, gdy coś się zmieniło — row_version zostaje bez zmian)
    ---------------------------------------------------------------------------------------------
    MERGE [catalog].[products] WITH (HOLDLOCK) AS t
    USING @products AS s
        ON t.[sku] = s.[sku]
    WHEN MATCHED AND EXISTS (
            SELECT s.[name], s.[category_code], s.[product_kind], s.[manufacturer_code], s.[cloud_provider_code], s.[unit_code], s.[list_price]
            EXCEPT
            SELECT t.[name], t.[category_code], t.[product_kind], t.[manufacturer_code], t.[cloud_provider_code], t.[unit_code], t.[list_price])
        THEN UPDATE SET
            t.[name]                = s.[name],
            t.[category_code]       = s.[category_code],
            t.[product_kind]        = s.[product_kind],
            t.[manufacturer_code]   = s.[manufacturer_code],
            t.[cloud_provider_code] = s.[cloud_provider_code],
            t.[unit_code]           = s.[unit_code],
            t.[list_price]          = s.[list_price]
    WHEN NOT MATCHED BY TARGET
        THEN INSERT ([sku], [name], [category_code], [product_kind], [manufacturer_code], [cloud_provider_code], [unit_code], [list_price], [currency_code])
             VALUES (s.[sku], s.[name], s.[category_code], s.[product_kind], s.[manufacturer_code], s.[cloud_provider_code], s.[unit_code], s.[list_price], 'PLN');

    ---------------------------------------------------------------------------------------------
    -- 5. Szczegóły: MERGE po product_id (id z products po SKU)
    ---------------------------------------------------------------------------------------------
    MERGE [catalog].[hardware_details] WITH (HOLDLOCK) AS t
    USING (SELECT p.[id] AS [product_id], h.* FROM @hardware h JOIN [catalog].[products] p ON p.[sku] = h.[sku]) AS s
        ON t.[product_id] = s.[product_id]
    WHEN MATCHED AND EXISTS (
            SELECT s.[form_factor], s.[cpu], s.[ram_gb], s.[storage], s.[port_count], s.[warranty_months]
            EXCEPT
            SELECT t.[form_factor], t.[cpu], t.[ram_gb], t.[storage], t.[port_count], t.[warranty_months])
        THEN UPDATE SET t.[form_factor] = s.[form_factor], t.[cpu] = s.[cpu], t.[ram_gb] = s.[ram_gb],
                        t.[storage] = s.[storage], t.[port_count] = s.[port_count], t.[warranty_months] = s.[warranty_months]
    WHEN NOT MATCHED BY TARGET
        THEN INSERT ([product_id], [form_factor], [cpu], [ram_gb], [storage], [port_count], [warranty_months])
             VALUES (s.[product_id], s.[form_factor], s.[cpu], s.[ram_gb], s.[storage], s.[port_count], s.[warranty_months]);

    MERGE [catalog].[license_details] WITH (HOLDLOCK) AS t
    USING (SELECT p.[id] AS [product_id], l.* FROM @license l JOIN [catalog].[products] p ON p.[sku] = l.[sku]) AS s
        ON t.[product_id] = s.[product_id]
    WHEN MATCHED AND EXISTS (
            SELECT s.[license_model], s.[metric], s.[term_months], s.[min_quantity]
            EXCEPT
            SELECT t.[license_model], t.[metric], t.[term_months], t.[min_quantity])
        THEN UPDATE SET t.[license_model] = s.[license_model], t.[metric] = s.[metric],
                        t.[term_months] = s.[term_months], t.[min_quantity] = s.[min_quantity]
    WHEN NOT MATCHED BY TARGET
        THEN INSERT ([product_id], [license_model], [metric], [term_months], [min_quantity])
             VALUES (s.[product_id], s.[license_model], s.[metric], s.[term_months], s.[min_quantity]);

    MERGE [catalog].[support_details] WITH (HOLDLOCK) AS t
    USING (SELECT p.[id] AS [product_id], x.* FROM @support x JOIN [catalog].[products] p ON p.[sku] = x.[sku]) AS s
        ON t.[product_id] = s.[product_id]
    WHEN MATCHED AND EXISTS (
            SELECT s.[billing_period], s.[sla_level], s.[response_hours], s.[support_hours]
            EXCEPT
            SELECT t.[billing_period], t.[sla_level], t.[response_hours], t.[support_hours])
        THEN UPDATE SET t.[billing_period] = s.[billing_period], t.[sla_level] = s.[sla_level],
                        t.[response_hours] = s.[response_hours], t.[support_hours] = s.[support_hours]
    WHEN NOT MATCHED BY TARGET
        THEN INSERT ([product_id], [billing_period], [sla_level], [response_hours], [support_hours])
             VALUES (s.[product_id], s.[billing_period], s.[sla_level], s.[response_hours], s.[support_hours]);

    MERGE [catalog].[cloud_details] WITH (HOLDLOCK) AS t
    USING (SELECT p.[id] AS [product_id], c.* FROM @cloud c JOIN [catalog].[products] p ON p.[sku] = c.[sku]) AS s
        ON t.[product_id] = s.[product_id]
    WHEN MATCHED AND EXISTS (
            SELECT s.[service_type], s.[billing_model], s.[term_months], s.[region]
            EXCEPT
            SELECT t.[service_type], t.[billing_model], t.[term_months], t.[region])
        THEN UPDATE SET t.[service_type] = s.[service_type], t.[billing_model] = s.[billing_model],
                        t.[term_months] = s.[term_months], t.[region] = s.[region]
    WHEN NOT MATCHED BY TARGET
        THEN INSERT ([product_id], [service_type], [billing_model], [term_months], [region])
             VALUES (s.[product_id], s.[service_type], s.[billing_model], s.[term_months], s.[region]);

    COMMIT TRANSACTION;

    -- Podsumowanie: liczba produktów z seeda per kategoria
    SELECT p.[category_code], COUNT(*) AS [products]
    FROM [catalog].[products] p
    WHERE p.[sku] IN (SELECT [sku] FROM @products)
    GROUP BY p.[category_code]
    ORDER BY p.[category_code];
END;
