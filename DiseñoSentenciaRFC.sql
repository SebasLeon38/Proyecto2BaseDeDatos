SELECT  l.nombre AS nombre_localidad, COUNT(s.idSolicitud) AS total_solicitudes
FROM  Solicitud s
INNER JOIN Parada p 
ON s.idparada = p.idparada
INNER JOIN Localidad l 
ON p.idlocalidad = l.idlocalidad
WHERE s.fechasolicitud BETWEEN TO_DATE(:P_FECHA_INICIO, 'MM/DD/YYYY') AND TO_DATE(:P_FECHA_FIN, 'MM/DD/YYYY')
GROUP BY  l.nombre
ORDER BY total_solicitudes DESC;

SELECT l.idlocalidad, l.nombre AS localidad, COUNT(s.idsolicitud) AS solicitudes_aceptadas,COUNT(DISTINCT v.idviaje) AS viajes_completados, NVL(SUM(v.costo), 0) AS ingresos_estimados
FROM localidad l
LEFT JOIN viaje v 
ON v.idlocalidadorigen = l.idlocalidad AND v.estado = 'Completado' AND v.fechasalida >= TRUNC(TO_DATE(:PXX_FECHA_INICIO, 'MM/DD/YYYY')) AND v.fechasalida <= TRUNC(TO_DATE(:PXX_FECHA_FIN, 'MM/DD/YYYY'))
LEFT JOIN solicitud s 
ON s.idviaje = v.idviaje AND s.estado = 'Aceptada'
GROUP BY l.idlocalidad, l.nombre
ORDER BY ingresos_estimados DESC;

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
