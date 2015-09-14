USE db_comercial_final
GO
-- =============================================
-- Author:		Paul Monge
-- Create date: 20121112
-- Description:	Datos de cliente en factura electrónica de tickets
-- =============================================
ALTER PROCEDURE [dbo].[_ven_prc_facturaClienteDatos]
	 @codcliente AS VARCHAR(30)
	,@idsucursal AS INT
AS

SET NOCOUNT ON

SELECT
	 [idcliente] = c.idcliente
	,[rfc] = cf.rfc
	,[cliente] = c.nombre
	,[direccion] = cf.direccion1
	,[telefono1] = cf.telefono1
	,[email] = cf.email
	,[idfacturacion] = c.idfacturacion
FROM
	ew_clientes AS c
	LEFT JOIN ew_clientes_facturacion AS cf
		ON cf.idcliente = c.idcliente
		AND cf.idfacturacion = c.idfacturacion
WHERE
	c.codigo = @codcliente
GO
