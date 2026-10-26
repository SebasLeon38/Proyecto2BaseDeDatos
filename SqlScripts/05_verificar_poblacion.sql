SELECT (SELECT COUNT(*) FROM conductor) AS conductores,
       (SELECT COUNT(*) FROM pasajero) AS pasajeros,
       (SELECT COUNT(*) FROM vehiculo) AS vehiculos,
       (SELECT COUNT(*) FROM viaje) AS viajes,
       (SELECT COUNT(*) FROM solicitud) AS solicitudes
FROM dual;

SELECT ROUND(AVG(n), 2) AS promedio_pasajeros_distintos, MIN(n) AS minimo, MAX(n) AS maximo
FROM (
    SELECT ve.documentoconductor, COUNT(DISTINCT s.documentopasajero) AS n
    FROM vehiculo ve
    JOIN viaje vi ON vi.placa = ve.placa
    JOIN solicitud s ON s.idviaje = vi.idviaje
    WHERE s.estado = 'Aceptada'
    GROUP BY ve.documentoconductor
);

SELECT estado, COUNT(*) AS total FROM viaje GROUP BY estado ORDER BY estado;
SELECT estado, COUNT(*) AS total FROM solicitud GROUP BY estado ORDER BY estado;
