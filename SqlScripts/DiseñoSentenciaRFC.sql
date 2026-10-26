-- RFC1--
SELECT  l.nombre AS nombre_localidad, COUNT(s.idSolicitud) AS total_solicitudes
FROM  Solicitud s
INNER JOIN Parada p 
ON s.idparada = p.idparada
INNER JOIN Localidad l 
ON p.idlocalidad = l.idlocalidad
WHERE s.fechasolicitud BETWEEN TO_DATE(:P_FECHA_INICIO, 'MM/DD/YYYY') AND TO_DATE(:P_FECHA_FIN, 'MM/DD/YYYY')
GROUP BY  l.nombre
ORDER BY total_solicitudes DESC;
--RFC2-
SELECT l.idlocalidad, l.nombre AS localidad, COUNT(s.idsolicitud) AS solicitudes_aceptadas,COUNT(DISTINCT v.idviaje) AS viajes_completados, NVL(SUM(v.costo), 0) AS ingresos_estimados
FROM localidad l
LEFT JOIN viaje v 
ON v.idlocalidadorigen = l.idlocalidad AND v.estado = 'Completado' AND v.fechasalida >= TRUNC(TO_DATE(:PXX_FECHA_INICIO, 'MM/DD/YYYY')) AND v.fechasalida <= TRUNC(TO_DATE(:PXX_FECHA_FIN, 'MM/DD/YYYY'))
LEFT JOIN solicitud s 
ON s.idviaje = v.idviaje AND s.estado = 'Aceptada'
GROUP BY l.idlocalidad, l.nombre
ORDER BY ingresos_estimados DESC;
--RFC3--
SELECT 
    c.documentoidentidad AS documento_conductor,
    e.nombre || ' ' || e.apellido AS nombre_conductor,
    v.idviaje,
    v.fechasalida,
    v.estado,
    l.idlocalidad,
    l.nombre AS localidad_origen,
    v.costo,
    v.distanciakm
FROM viaje v
INNER JOIN vehiculo ve ON v.placa = ve.placa
INNER JOIN conductor c ON ve.documentoconductor = c.documentoidentidad
INNER JOIN estudiante e ON c.documentoidentidad = e.documentoidentidad
INNER JOIN localidad l ON v.idlocalidadorigen = l.idlocalidad
WHERE (:PXX_CONDUCTOR IS NULL OR c.documentoidentidad = :PXX_CONDUCTOR)
  AND (:PXX_LOCALIDAD IS NULL OR l.idlocalidad = :PXX_LOCALIDAD)
  AND v.fechasalida >= TRUNC(TO_DATE(:PXX_FECHA_INICIO, 'MM/DD/YYYY'))
  AND v.fechasalida <= TRUNC(TO_DATE(:PXX_FECHA_FIN, 'MM/DD/YYYY'))
ORDER BY c.documentoidentidad, v.fechasalida ASC;


--RFA1--
--CONDUCTOR: --
SELECT e.nombre || ' ' || e.apellido AS d, c.documentoidentidad AS r 
FROM conductor c 
JOIN estudiante e ON c.documentoidentidad = e.documentoidentidad 
ORDER BY e.nombre;
--PASAJEROS: --
SELECT COUNT(s.idsolicitud) AS total_pasajeros
FROM viaje v
JOIN vehiculo ve ON v.placa = ve.placa
JOIN solicitud s ON s.idviaje = v.idviaje
WHERE ve.documentoconductor = :P_CONDUCTOR
  AND v.estado = 'Completado'
  AND s.estado = 'Aceptada';
--TIEMPO: --
SELECT NVL(SUM(v.fechallegada - v.fechasalida) * 24, 0) AS total_horas_viaje
FROM viaje v
JOIN vehiculo ve ON v.placa = ve.placa
WHERE ve.documentoconductor = :P_CONDUCTOR
  AND v.estado = 'Completado'
  AND v.fechallegada IS NOT NULL;
--INGRESOS:--
SELECT NVL(SUM(v.costo), 0) AS ingresos_totales
FROM viaje v
JOIN vehiculo ve ON v.placa = ve.placa
WHERE ve.documentoconductor = :P_CONDUCTOR
  AND v.estado = 'Completado';
--DISTANCIA:--
SELECT NVL(SUM(v.distanciakm), 0) AS distancia_total_km
FROM viaje v
JOIN vehiculo ve ON v.placa = ve.placa
WHERE ve.documentoconductor = :P_CONDUCTOR
  AND v.estado = 'Completado';


--RFA2--
--P2_PASAJERO:--
SELECT e.nombre || ' ' || e.apellido AS d, p.documentoidentidad AS r 
FROM pasajero p 
JOIN estudiante e ON p.documentoidentidad = e.documentoidentidad 
ORDER BY e.nombre;
--VIAJES: --
SELECT COUNT(DISTINCT s.idviaje) AS total_viajes
FROM solicitud s
WHERE s.documentopasajero = :P_PASAJERO
  AND s.estado = 'Aceptada';
--FRECUENCIA: --
SELECT l.nombre AS zona_frecuente
FROM solicitud s
JOIN viaje v ON s.idviaje = v.idviaje
JOIN localidad l ON v.idlocalidadorigen = l.idlocalidad
WHERE s.documentopasajero = :P_PASAJERO
GROUP BY l.nombre
ORDER BY COUNT(s.idsolicitud) DESC
FETCH FIRST 1 ROWS ONLY;
--GASTOS:--
SELECT NVL(SUM(v.costo), 0) AS total_gastos
FROM solicitud s
JOIN viaje v ON s.idviaje = v.idviaje
WHERE s.documentopasajero = :P_PASAJERO
  AND s.estado = 'Aceptada';
--DISTANCIA:--
SELECT ROUND(NVL(AVG(v.distanciakm), 0), 2) AS promedio_distancia_km
FROM solicitud s
JOIN viaje v ON s.idviaje = v.idviaje
WHERE s.documentopasajero = :P_PASAJERO
  AND s.estado = 'Aceptada';
--TIEMPO: --
SELECT ROUND(NVL(AVG(v.fechallegada - v.fechasalida) * 24 * 60, 0), 2) AS promedio_tiempo_minutos
FROM solicitud s
JOIN viaje v ON s.idviaje = v.idviaje
WHERE s.documentopasajero = :P_PASAJERO
  AND s.estado = 'Aceptada'
  AND v.fechallegada IS NOT NULL;
