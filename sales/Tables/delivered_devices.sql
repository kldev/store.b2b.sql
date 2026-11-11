-- Dostarczone egzemplarze sprzętu (numery seryjne, gwarancja) z pozycji zamówienia.
CREATE TABLE [sales].[delivered_devices]
(
    [id]             BIGINT           IDENTITY(1, 1) NOT NULL,
    [order_line_id]  BIGINT           NOT NULL,
    [serial_number]  VARCHAR(60)      NOT NULL,
    [delivered_on]   DATE             NOT NULL,
    [warranty_until] DATE             NULL,
    [created_at]     DATETIME2(3)     NOT NULL CONSTRAINT [df_sales_delivered_devices_created_at] DEFAULT SYSUTCDATETIME(),
    CONSTRAINT [pk_sales_delivered_devices] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [ux_sales_delivered_devices_order_line_serial] UNIQUE ([order_line_id], [serial_number]),
    CONSTRAINT [fk_sales_delivered_devices_order_line] FOREIGN KEY ([order_line_id]) REFERENCES [sales].[order_lines] ([id]),
    CONSTRAINT [ck_sales_delivered_devices_warranty] CHECK ([warranty_until] IS NULL OR [warranty_until] >= [delivered_on])
);
GO
CREATE NONCLUSTERED INDEX [ix_sales_delivered_devices_serial_number] ON [sales].[delivered_devices] ([serial_number]);
