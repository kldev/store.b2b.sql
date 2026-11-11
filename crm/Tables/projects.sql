-- Projekt klienta (np. modernizacja serwerowni, migracja do chmury).
CREATE TABLE [crm].[projects]
(
    [id]          BIGINT           IDENTITY(1, 1) NOT NULL,
    [client_id]   BIGINT           NOT NULL,
    [name]        NVARCHAR(200)    NOT NULL,
    [status]      VARCHAR(20)      NOT NULL CONSTRAINT [df_crm_projects_status] DEFAULT 'planned',
    [start_date]  DATE             NULL,
    [end_date]    DATE             NULL,
    [created_at]  DATETIME2(3)     NOT NULL CONSTRAINT [df_crm_projects_created_at] DEFAULT SYSUTCDATETIME(),
    [row_version] ROWVERSION       NOT NULL,
    CONSTRAINT [pk_crm_projects] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [fk_crm_projects_client] FOREIGN KEY ([client_id]) REFERENCES [crm].[clients] ([id]),
    -- Cel złożonych FK (client_id, project_id): projekt musi należeć do tego samego klienta.
    CONSTRAINT [ux_crm_projects_client_id_id] UNIQUE ([client_id], [id]),
    CONSTRAINT [ck_crm_projects_status] CHECK ([status]      IN ('planned', 'active', 'on_hold', 'completed', 'cancelled')),
    CONSTRAINT [ck_crm_projects_dates] CHECK ([end_date] IS NULL OR [start_date] IS NULL OR [end_date] >= [start_date])
);
