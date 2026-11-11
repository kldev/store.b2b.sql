CREATE PROCEDURE [crm].[seed_clients]  -- wstawia testowych klientów
    @count int = 5000                               -- ile rekordów wstawić; domyślnie 5000
AS
BEGIN
    SET NOCOUNT ON;                                 -- nie wysyłaj komunikatów "(n rows affected)"
    SET XACT_ABORT ON;                              -- przy dowolnym błędzie wycofaj całą transakcję

    IF @count IS NULL OR @count < 1 OR @count > 1000000                 -- sprawdź, czy liczba ma sens
        THROW 50001, N'@count musi być w zakresie 1..1000000.', 1;      -- jeśli nie, przerwij z własnym błędem

    BEGIN TRANSACTION;                              -- wszystko albo nic

    -- Przesunięcie numeracji, żeby kolejne uruchomienia nie dublowały NIP-u ani e-maila
    DECLARE @offset bigint =                        -- punkt startowy numeracji tego uruchomienia
        ISNULL((SELECT MAX(id) FROM crm.clients     -- największe id w tabeli (NULL, gdy tabela pusta → 0)
                WITH (UPDLOCK, HOLDLOCK)), 0);      -- zablokuj odczyt do końca transakcji, żeby dwa wywołania naraz nie wzięły tego samego MAX

    WITH digits AS (                                -- CTE 1: dziesięć cyfr 0..9
        SELECT d FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v(d)
    ),
    numbers AS (                                    -- CTE 2: kolejne liczby 1..@count
        SELECT TOP (@count)                         -- weź tylko tyle, ile potrzeba
               CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS bigint) AS n   -- numeruj wiersze 1, 2, 3... (kolejność obojętna)
        FROM digits a CROSS JOIN digits b CROSS JOIN digits c                   -- 10 × 10 × 10 = 1000 kombinacji...
             CROSS JOIN digits d CROSS JOIN digits e CROSS JOIN digits f        -- ...× 1000 = do 1 000 000 wierszy
    ),
    src AS (                                        -- CTE 3: wartości pomocnicze dla każdego wiersza
        SELECT n,                                   -- numer wiersza w tym uruchomieniu (1..@count)
               k = @offset + n,                     -- numer globalnie unikalny (do NIP-u, e-maila, nazwy)
               is_company = CASE WHEN n % 3 = 0 THEN 0 ELSE 1 END   -- co trzeci wiersz to osoba, reszta to firmy
        FROM numbers
    )
    INSERT INTO crm.clients                         -- wstaw do tabeli klientów...
        (kind, name, tax_id, registry_id, email, phone, website,       -- ...te kolumny (id, created_at, updated_at,
         street, postal_code, city, country_code, status, source,      --    row_version wypełni baza sama)
         owner_user_id, notes)
    SELECT
        CASE WHEN is_company = 1 THEN 'company' ELSE 'person' END,     -- kind: firma albo osoba
        CASE WHEN is_company = 1                                        -- name dla firmy:
             THEN CONCAT(CHOOSE(n % 6 + 1, N'Alfa', N'Beta', N'Gamma', N'Delta', N'Omega', N'Sigma'),   -- człon nazwy z listy
                         N' ',
                         CHOOSE(n % 4 + 1, N'Sp. z o.o.', N'S.A.', N'Sp.j.', N'Sp.k.'),                 -- forma prawna z listy
                         N' #', k)                                                                      -- numer, żeby nazwy się nie powtarzały
             ELSE CONCAT(CHOOSE(n % 6 + 1, N'Anna', N'Jan', N'Katarzyna', N'Piotr', N'Małgorzata', N'Tomasz'),          -- name dla osoby: imię
                         N' ',
                         CHOOSE(n % 6 + 1, N'Kowalska', N'Nowak', N'Wiśniewska', N'Wójcik', N'Kamińska', N'Lewandowski'), -- nazwisko
                         N' #', k)                                                                                      -- numer
        END,
        CASE WHEN is_company = 1 THEN CONCAT('9', RIGHT(CONCAT('000000000', k), 9)) END,  -- tax_id: '9' + 9 cyfr z k = 10-cyfrowy NIP (osoba: NULL)
        CASE WHEN is_company = 1 THEN RIGHT(CONCAT('000000000', k), 9) END,               -- registry_id: 9-cyfrowy REGON (osoba: NULL)
        CONCAT(N'client', k, N'@example.com'),                                            -- email: unikalny dzięki k
        CONCAT('+48 ', 500000000 + k % 499999999),                                        -- phone: 9 cyfr zaczynające się od 5
        CASE WHEN is_company = 1 THEN CONCAT(N'https://client', k, N'.example.com') END,  -- website: tylko firmy
        CONCAT(CHOOSE(n % 5 + 1, N'ul. Długa ', N'ul. Polna ', N'ul. Leśna ', N'al. Jerozolimskie ', N'ul. Słoneczna '),  -- street: ulica z listy...
               n % 200 + 1),                                                                                                -- ...i numer 1..200
        CONCAT(RIGHT(CONCAT('0', n % 99 + 1), 2), '-', RIGHT(CONCAT('00', n % 999 + 1), 3)), -- postal_code: format 00-000
        CHOOSE(n % 8 + 1, N'Warszawa', N'Kraków', N'Wrocław', N'Poznań', N'Gdańsk', N'Łódź', N'Lublin', N'Katowice'),  -- city: miasto z listy
        'PL',                                                                             -- country_code: zawsze Polska
        CHOOSE(n % 5 + 1, 'lead', 'prospect', 'active', 'inactive', 'lost'),              -- status: po równo każdy z pięciu
        CHOOSE(n % 4 + 1, N'www', N'polecenie', N'targi', N'kampania'),                   -- source: po równo każde z czterech
        n % 10 + 1,                                                                       -- owner_user_id: opiekunowie 1..10
        CASE WHEN n % 7 = 0 THEN N'Klient testowy - wygenerowany przez crm.seed_clients' END  -- notes: co siódmy wiersz ma notatkę
    FROM src;                                       -- jeden wiersz wynikowy na każdą liczbę z CTE

    DECLARE @inserted int = @@ROWCOUNT;             -- ile wierszy wstawił INSERT (odczyt zaraz po nim!)

    COMMIT TRANSACTION;                             -- zatwierdź zmiany i zwolnij blokadę

    SELECT @inserted AS inserted_rows;              -- zwróć wywołującemu liczbę wstawionych wierszy
END;
