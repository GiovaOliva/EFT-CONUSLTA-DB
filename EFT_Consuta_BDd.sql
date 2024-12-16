-- Primero creamos las tablas con el script proporcionado.
-- Y continuamos con poblarlas con los datos proporcionados.

-- INFORME 1
-- Procedemos con una consulta antes de crear la vista
SELECT r.nombre_region, 
       COUNT(CASE WHEN EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM c.fecha_inscripcion) >= 20 THEN 1 END) AS clientes_20_anios,
       COUNT(*) AS total_clientes
FROM cliente c
JOIN region r ON c.cod_region = r.cod_region
GROUP BY r.nombre_region
ORDER BY clientes_20_anios ASC;

-- Creamos la vista
CREATE OR REPLACE VIEW vista_clientes_20_anios AS
SELECT r.nombre_region, 
       COUNT(CASE WHEN EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM c.fecha_inscripcion) >= 20 THEN 1 END) AS clientes_20_anios,
       COUNT(*) AS total_clientes
FROM cliente c
JOIN region r ON c.cod_region = r.cod_region
GROUP BY r.nombre_region;

-- Implementamos los INDEX
CREATE INDEX IDX_REGION ON cliente(cod_region);
CREATE INDEX IDX_CLI_REGION ON cliente(fecha_inscripcion, cod_region);

-- INFORME 2

-- Creamos vista con operador SET
CREATE OR REPLACE VIEW vista_transacciones_set AS
SELECT TO_CHAR(SYSDATE, 'DD-MM-YYYY') AS FECHA,
       t.cod_tptran_tarjeta AS CODIGO,
       t.nombre_tptran_tarjeta AS DESCRIPCION,
       ROUND(AVG(tt.monto_transaccion)) AS MONTO_PROMEDIO
FROM transaccion_tarjeta_cliente tt
INNER JOIN tipo_transaccion_tarjeta t 
    ON tt.cod_tptran_tarjeta = t.cod_tptran_tarjeta
WHERE EXTRACT(MONTH FROM tt.fecha_transaccion) BETWEEN 6 AND 9
GROUP BY t.cod_tptran_tarjeta, t.nombre_tptran_tarjeta

UNION ALL

SELECT TO_CHAR(SYSDATE, 'DD-MM-YYYY') AS FECHA,
       t.cod_tptran_tarjeta AS CODIGO,
       t.nombre_tptran_tarjeta AS DESCRIPCION,
       ROUND(AVG(tt.monto_transaccion)) AS MONTO_PROMEDIO
FROM transaccion_tarjeta_cliente tt
INNER JOIN tipo_transaccion_tarjeta t 
    ON tt.cod_tptran_tarjeta = t.cod_tptran_tarjeta
WHERE EXTRACT(MONTH FROM tt.fecha_transaccion) BETWEEN 10 AND 12
GROUP BY t.cod_tptran_tarjeta, t.nombre_tptran_tarjeta
ORDER BY MONTO_PROMEDIO ASC;

-- Creamos la vista con subconsultas
CREATE OR REPLACE VIEW vista_transacciones_subconsulta AS
SELECT TO_CHAR(SYSDATE, 'DD-MM-YYYY') AS FECHA,
       t.cod_tptran_tarjeta AS CODIGO,
       t.nombre_tptran_tarjeta AS DESCRIPCION,
       ROUND(AVG(tt.monto_transaccion)) AS MONTO_PROMEDIO
FROM (
    SELECT tt.cod_tptran_tarjeta, tt.monto_transaccion, tt.fecha_transaccion
    FROM transaccion_tarjeta_cliente tt
    WHERE EXTRACT(MONTH FROM tt.fecha_transaccion) BETWEEN 6 AND 12
) tt
INNER JOIN tipo_transaccion_tarjeta t 
    ON tt.cod_tptran_tarjeta = t.cod_tptran_tarjeta
GROUP BY t.cod_tptran_tarjeta, t.nombre_tptran_tarjeta
ORDER BY MONTO_PROMEDIO ASC;

-- Insertamos el resultado de la subconsulta en SELECCION_TIPO_TRANSACCION
INSERT INTO SELECCION_TIPO_TRANSACCION (COD_TIPO_TRANSAC, NOMBRE_TIPO_TRANSAC, MONTO_PROMEDIO)
SELECT CODIGO, DESCRIPCION, MONTO_PROMEDIO
FROM vista_transacciones_subconsulta;


-- Rebajamos la tasa de inter�s en 1% para los tipos de transacci�n seleccionados
UPDATE tipo_transaccion_tarjeta ttt
SET ttt.tasaint_tptran_tarjeta = ttt.tasaint_tptran_tarjeta - 0.01
WHERE ttt.cod_tptran_tarjeta IN (
    SELECT DISTINCT stt.cod_tipo_transac
    FROM SELECCION_TIPO_TRANSACCION stt
);

-- RESPUESTAS A LAS PREGUNTAS DEL INFORME 2

-- 1. �Cu�l es el problema que se debe resolver?
-- El problema consiste en visualizar las transacciones cuyas cuotas vencen entre junio y diciembre, 
-- ordenadas por el promedio de montos de transacciones. 
-- Adem�s, se requiere actualizar la tasa de inter�s de las transacciones seleccionadas aplicando una rebaja del 1%.

-- 2. �Cu�l es la informaci�n significativa que necesita para resolver el problema?
-- La informaci�n de la tabla transaccion_tarjeta_cliente, en particular:
--    - fecha_transaccion: Para identificar las transacciones entre junio y diciembre.
--    - monto_transaccion: Para calcular el promedio de los montos.
--    - cod_tptran_tarjeta: Identificador para relacionar con la descripci�n del tipo de transacci�n.
-- La informaci�n de la tabla tipo_transaccion_tarjeta:
--    - cod_tptran_tarjeta: Clave para unir con la tabla de clientes.
--    - nombre_tptran_tarjeta: Para obtener la descripci�n del tipo de transacci�n.
--    - tasaint_tptran_tarjeta: Para aplicar la rebaja del 1%.
-- La tabla SELECCION_TIPO_TRANSACCION: Para almacenar los resultados de la subconsulta.

-- 3. �Cu�l es el prop�sito de la soluci�n que se requiere?
-- El prop�sito es:
--    - Visualizar las transacciones con vencimientos en el segundo semestre (junio-diciembre).
--    - Ordenar las transacciones por el promedio de montos de manera ascendente.
--    - Implementar dos soluciones: una usando OPERADOR SET (UNION ALL) y otra con SUBCONSULTAS.
--    - Actualizar la tasa de inter�s del tipo de transacci�n con una rebaja del 1% usando los datos generados.

-- 4. Detalle los pasos necesarios para construir la alternativa que usa SUBCONSULTA.
-- Paso 1: Seleccionar los datos de la tabla transaccion_tarjeta_cliente filtrando por los meses entre 6 (junio) y 12 (diciembre).
-- Paso 2: Crear una subconsulta para obtener las transacciones filtradas.
-- Paso 3: Unir la subconsulta con la tabla tipo_transaccion_tarjeta utilizando cod_tptran_tarjeta como clave.
-- Paso 4: Calcular el promedio de montos de transacciones usando la funci�n AVG.
-- Paso 5: Agrupar los resultados por cod_tptran_tarjeta y nombre_tptran_tarjeta.
-- Paso 6: Ordenar los resultados por promedio de montos (ASC).
-- Paso 7: Almacenar los resultados en la tabla SELECCION_TIPO_TRANSACCION.

-- 5. Detalle los pasos necesarios para construir la alternativa que usa OPERADOR SET.
-- Paso 1: Seleccionar los datos de la tabla transaccion_tarjeta_cliente en dos bloques separados.
-- Paso 2: Filtrar las transacciones entre junio (6) y septiembre (9) y octubre (10) a diciembre (12).
-- Paso 3: Calcular el promedio de montos en ambos bloques.
-- Paso 4: Unir los bloques con UNION ALL.
-- Paso 5: Agrupar y ordenar por cod_tptran_tarjeta y promedio de montos.