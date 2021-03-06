USE [db_comercial_final]
GO
ALTER PROCEDURE [dbo].[_ven_prc_facturaCancelar]
	@idtran AS BIGINT
	,@fecha AS SMALLDATETIME
	,@idu AS SMALLINT
	,@password AS VARCHAR(20)
AS

SET NOCOUNT ON

DECLARE
	@idtran2 AS BIGINT
	,@idtran_inv AS BIGINT
	,@usuario AS VARCHAR(20)
	,@sql AS VARCHAR(4000)
	,@msg AS VARCHAR(250)
	,@transaccion AS VARCHAR(5)
	,@folio AS VARCHAR(15)
	,@comentario2 AS VARCHAR(250)
	,@codalm AS SMALLINT
	,@surtir AS SMALLINT
	
SELECT 
	@usuario = usuario 
FROM 
	ew_usuarios 
WHERE idu = @idu

SELECT 
	@transaccion = transaccion
	, @folio = folio
	, @codalm = idalmacen 
FROM 
	ew_ven_transacciones 
WHERE 
	idtran = @idtran

-- cancelamos el cargo en CXC
EXEC _cxc_prc_cancelarTransaccion @idtran, @fecha, @idu

--------------------------------------------------------------------
-- Afectamos el inventario
--------------------------------------------------------------------
SELECT TOP 1 
	@idtran2 = ISNULL(idtran,0) 
FROM 
	ew_inv_transacciones 
WHERE 
	idtran2 = @idtran 
	AND idconcepto = 19

IF @idtran2 > 0
BEGIN
	IF EXISTS(
		SELECT fm.idarticulo 
		FROM 
			ew_inv_transacciones_mov AS fm
		WHERE 
			fm.cantidad > 0 
			AND fm.idtran = @idtran2
	)
	BEGIN
		SELECT @sql = '', @idtran_inv = 0

		SELECT @sql = 'SELECT idmov AS [idmov2],idpedimento,[idcapa]=0,idarticulo,series,lote=ISNULL(lote,''''),fecha_caducidad,idum
	,cantidad=cantidad,costo,costo2, [afectaref]=1
FROM
	ew_inv_transacciones_mov fm
WHERE
	(idtran=' + CONVERT(VARCHAR(8),@idtran2) + ') 
		'

		SELECT @comentario2 = RTRIM(@transaccion) + ': ' + RTRIM(@folio) + ' - Cancelación Ventas'

		EXEC _inv_prc_insertarTransaccion2
			@idtran
			, 1019
			, @codalm
			, @fecha
			, 1
			, @usuario
			, @password
			, ''
			, @comentario2
			, @sql
			, @idtran_inv OUTPUT 

		IF @idtran_inv IS NULL OR @idtran_inv = 0
		BEGIN
			SELECT @msg='Error. Al cancelar la factura en el inventario ...'
			RAISERROR(@msg, 16, 1)
			RETURN
		END 
	END
END

--------------------------------------------------------------------
-- Reactivamos la mercancia surtida en la orden 
--------------------------------------------------------------------
INSERT INTO ew_sys_movimientos_acumula (
	idmov1
	,idmov2
	,campo
	,valor
)
SELECT 
	m.idmov
	,m.idmov2
	,'cantidad_surtida'
	,m.cantidad_surtida * (-1)
FROM
	ew_ven_transacciones_mov m
	LEFT JOIN ew_articulos a 
		ON a.idarticulo = m.idarticulo
WHERE 
	idtran = @idtran
	AND m.cantidad_surtida != 0

--------------------------------------------------------------------
-- Reactivamos la mercancia facturada en la orden 
--------------------------------------------------------------------
INSERT INTO ew_sys_movimientos_acumula (
	idmov1
	,idmov2
	,campo
	,valor
)
SELECT 
	idmov
	,idmov2
	,'cantidad_facturada'
	,cantidad_facturada  * (-1)
FROM
	ew_ven_transacciones_mov
WHERE 
	idtran = @idtran
	AND cantidad_facturada!=0

--------------------------------------------------------------------
-- Reabrimos los pedidos
--------------------------------------------------------------------
DECLARE cur_detalle1 CURSOR FOR
	SELECT DISTINCT 
		[idtran] = CONVERT(INT, FLOOR(fm.idmov2))
	FROM
		ew_ven_transacciones_mov fm 
	WHERE
		fm.cantidad_facturada > 0
		AND CONVERT(INT, FLOOR(fm.idmov2)) > 0
		AND fm.idtran = @idtran

OPEN cur_detalle1

FETCH NEXT FROM cur_detalle1 INTO @idtran2

WHILE @@fetch_status = 0
BEGIN
	EXEC _ven_prc_ordenEstado @idtran2

	FETCH NEXT FROM cur_detalle1 INTO @idtran2
END

CLOSE cur_detalle1
DEALLOCATE cur_detalle1

UPDATE ew_cxc_transacciones SET 
	cancelado = '1'
	, cancelado_fecha = @fecha
	, saldo = 0 
WHERE
	idtran = @idtran

UPDATE ew_ven_transacciones SET
	cancelado = '1'
	, cancelado_fecha = @fecha
WHERE
	idtran = @idtran
GO
