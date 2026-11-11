-- Pozycja zamówienia; cena zapisana w chwili sprzedaży.
CREATE TABLE [sales].[order_lines]
(
    [id]               BIGINT           IDENTITY(1, 1) NOT NULL,
    [order_id]         BIGINT           NOT NULL,
    [line_no]          INT              NOT NULL,
    [product_id]       BIGINT           NOT NULL,
    [description]      NVARCHAR(500)    NULL,
    [quantity]         DECIMAL(19, 4)   NOT NULL,
    [unit_price]       DECIMAL(19, 4)   NOT NULL,
    [discount_percent] DECIMAL(5, 2)    NOT NULL CONSTRAINT [df_sales_order_lines_discount_percent] DEFAULT 0,
    [service_from]     DATE             NULL,
    [service_to]       DATE             NULL,
    [row_version]      ROWVERSION       NOT NULL,
    CONSTRAINT [pk_sales_order_lines] PRIMARY KEY CLUSTERED ([id]),
    CONSTRAINT [ux_sales_order_lines_order_line_no] UNIQUE ([order_id], [line_no]),
    CONSTRAINT [fk_sales_order_lines_order] FOREIGN KEY ([order_id]) REFERENCES [sales].[orders] ([id]),
    CONSTRAINT [fk_sales_order_lines_product] FOREIGN KEY ([product_id]) REFERENCES [catalog].[products] ([id]),
    CONSTRAINT [ck_sales_order_lines_line_no] CHECK ([line_no] > 0),
    CONSTRAINT [ck_sales_order_lines_quantity] CHECK ([quantity] > 0),
    CONSTRAINT [ck_sales_order_lines_unit_price] CHECK ([unit_price] >= 0),
    CONSTRAINT [ck_sales_order_lines_discount_percent] CHECK ([discount_percent] BETWEEN 0 AND 100),
    CONSTRAINT [ck_sales_order_lines_service_period] CHECK ([service_to] IS NULL OR [service_from] IS NULL OR [service_to] >= [service_from])
);
GO
CREATE NONCLUSTERED INDEX [ix_sales_order_lines_product_id] ON [sales].[order_lines] ([product_id]);
