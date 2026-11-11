-- Jednostki sprzedaży (sztuka, licencja, godzina, miesiąc, zużycie).
CREATE TABLE [catalog].[units]
(
    [code] VARCHAR(20)  NOT NULL,
    [name] NVARCHAR(50) NOT NULL,
    CONSTRAINT [pk_catalog_units] PRIMARY KEY CLUSTERED ([code])
);
