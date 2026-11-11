# B2B Store SQL Project

Projekt bazy danych Azure SQL (SDK `Microsoft.Build.Sql`). Schematy: `catalog`, `crm`, `sales`; skrypt po wdrożeniu: [Scripts/Script.PostDeployment.sql](Scripts/Script.PostDeployment.sql).

## Wymagania

- .NET SDK
- `sqlpackage`:

  ```bash
  dotnet tool install -g microsoft.sqlpackage
  ```

- Azure CLI zalogowane na konto z dostępem do bazy (`az login`) — z tego korzysta uwierzytelnianie `Active Directory Default`.

## Budowanie

```bash
dotnet build store.sqlproj
```

Wynik: `bin/Debug/store.dacpac`.

## Wdrożenie

```bash
sqlpackage /Action:Publish \
  /SourceFile:bin/Debug/store.dacpac \
  /TargetConnectionString:"Server=tcp:store.database.windows.net,1433;Initial Catalog=store;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default"
```
