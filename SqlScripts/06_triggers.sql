CREATE OR REPLACE TRIGGER trg_viaje_insert
BEFORE INSERT ON viaje
FOR EACH ROW
BEGIN
    IF :NEW.estado IS NULL OR :NEW.estado <> 'Programado' THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Un viaje nuevo debe crearse en estado Programado'
        );
    END IF;

    IF :NEW.fechasalida IS NULL OR :NEW.fechasalida <= SYSDATE THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'La fecha de salida debe ser futura'
        );
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_viaje_cupos
BEFORE INSERT OR UPDATE OF cuposdisponibles, placa ON viaje
FOR EACH ROW
DECLARE
    v_cupos vehiculo.cupos%TYPE;
BEGIN
    IF :NEW.cuposdisponibles IS NULL OR :NEW.cuposdisponibles < 0 THEN
        RAISE_APPLICATION_ERROR(
            -20007,
            'Los cupos disponibles deben ser mayores o iguales a cero'
        );
    END IF;

    IF :NEW.placa IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20008,
            'El viaje debe tener un vehiculo asociado'
        );
    END IF;

    BEGIN
        SELECT cupos
          INTO v_cupos
          FROM vehiculo
         WHERE placa = :NEW.placa;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20009,
                'No existe un vehiculo con la placa indicada'
            );
    END;

    IF v_cupos IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20015,
            'La capacidad del vehiculo no puede ser nula'
        );
    END IF;

    IF :NEW.cuposdisponibles > v_cupos THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Los cupos del viaje no pueden superar los cupos del vehiculo'
        );
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_viaje_estado
FOR UPDATE OF estado ON viaje
COMPOUND TRIGGER

    TYPE t_ids IS TABLE OF viaje.idviaje%TYPE;
    g_cancelados t_ids := t_ids();

    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.estado IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20016,
                'El estado del viaje no puede ser nulo'
            );
        END IF;

        IF :OLD.estado = :NEW.estado THEN
            NULL;

        ELSIF :OLD.estado IN ('Completado', 'Cancelado') THEN
            RAISE_APPLICATION_ERROR(
                -20004,
                'No se puede modificar el estado de un viaje completado o cancelado'
            );

        ELSIF :OLD.estado = 'Programado'
          AND :NEW.estado = 'En curso' THEN
            NULL;

        ELSIF :OLD.estado = 'En curso'
          AND :NEW.estado = 'Completado' THEN
            IF :NEW.fechallegada IS NULL THEN
                :NEW.fechallegada := SYSDATE;
            END IF;

        ELSIF :OLD.estado = 'Programado'
          AND :NEW.estado = 'Cancelado' THEN
            IF :OLD.fechasalida IS NULL
               OR SYSDATE > :OLD.fechasalida - (2 / 24) THEN
                RAISE_APPLICATION_ERROR(
                    -20005,
                    'El viaje solo puede cancelarse con al menos 2 horas de anticipacion'
                );
            END IF;

        ELSE
            RAISE_APPLICATION_ERROR(
                -20006,
                'Transicion de estado invalida'
            );
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF :OLD.estado <> 'Cancelado'
           AND :NEW.estado = 'Cancelado' THEN
            g_cancelados.EXTEND;
            g_cancelados(g_cancelados.LAST) := :NEW.idviaje;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF g_cancelados.COUNT > 0 THEN
            FOR i IN 1 .. g_cancelados.COUNT LOOP
                UPDATE solicitud
                   SET estado = 'Cancelada'
                 WHERE idviaje = g_cancelados(i)
                   AND estado IN ('Pendiente', 'Aceptada');
            END LOOP;
        END IF;

        g_cancelados.DELETE;
    END AFTER STATEMENT;
END trg_viaje_estado;
/

CREATE OR REPLACE TRIGGER trg_solicitud_insert
BEFORE INSERT ON solicitud
FOR EACH ROW
DECLARE
    v_estado    viaje.estado%TYPE;
    v_cupos     viaje.cuposdisponibles%TYPE;
    v_conductor vehiculo.documentoconductor%TYPE;
BEGIN
    IF :NEW.estado IS NULL OR :NEW.estado <> 'Pendiente' THEN
        RAISE_APPLICATION_ERROR(
            -20010,
            'Una solicitud nueva debe crearse en estado Pendiente'
        );
    END IF;

    IF :NEW.idviaje IS NULL OR :NEW.documentopasajero IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20017,
            'La solicitud debe indicar el viaje y el pasajero'
        );
    END IF;

    BEGIN
        SELECT v.estado, v.cuposdisponibles, ve.documentoconductor
          INTO v_estado, v_cupos, v_conductor
          FROM viaje v
          JOIN vehiculo ve ON ve.placa = v.placa
         WHERE v.idviaje = :NEW.idviaje;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20014,
                'No existe el viaje o no se encontro su vehiculo asociado'
            );
    END;

    IF v_estado <> 'Programado' THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'Solo se puede solicitar cupo en viajes programados'
        );
    END IF;

    IF v_cupos IS NULL OR v_cupos <= 0 THEN
        RAISE_APPLICATION_ERROR(
            -20012,
            'El viaje no tiene cupos disponibles'
        );
    END IF;

    IF v_conductor = :NEW.documentopasajero THEN
        RAISE_APPLICATION_ERROR(
            -20013,
            'El conductor no puede solicitar cupo en su propio viaje'
        );
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_solicitud_estado
BEFORE UPDATE OF estado ON solicitud
FOR EACH ROW
DECLARE
    v_estado_viaje viaje.estado%TYPE;
    v_cupos        viaje.cuposdisponibles%TYPE;
    v_salida       viaje.fechasalida%TYPE;
BEGIN
    IF :NEW.estado IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20025,
            'El estado de la solicitud no puede ser nulo'
        );
    END IF;

    IF :OLD.estado = :NEW.estado THEN
        RETURN;
    END IF;

    IF :OLD.estado IN ('Rechazada', 'Cancelada') THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            'No se puede modificar una solicitud rechazada o cancelada'
        );
    END IF;

    IF :OLD.estado = 'Pendiente'
       AND :NEW.estado NOT IN ('Aceptada', 'Rechazada', 'Cancelada') THEN
        RAISE_APPLICATION_ERROR(
            -20026,
            'Transicion de estado de solicitud invalida'
        );
    END IF;

    IF :OLD.estado = 'Aceptada'
       AND :NEW.estado <> 'Cancelada' THEN
        RAISE_APPLICATION_ERROR(
            -20021,
            'Una solicitud aceptada solo puede cancelarse'
        );
    END IF;

    IF :OLD.estado NOT IN ('Pendiente', 'Aceptada') THEN
        RAISE_APPLICATION_ERROR(
            -20027,
            'El estado actual de la solicitud no permite modificaciones'
        );
    END IF;

    BEGIN
        SELECT estado, cuposdisponibles, fechasalida
          INTO v_estado_viaje, v_cupos, v_salida
          FROM viaje
         WHERE idviaje = :NEW.idviaje
         FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20028,
                'No existe el viaje asociado a la solicitud'
            );
    END;

    IF :NEW.estado = 'Aceptada' THEN
        IF v_estado_viaje <> 'Programado' THEN
            RAISE_APPLICATION_ERROR(
                -20022,
                'Solo se pueden aceptar solicitudes de viajes programados'
            );
        END IF;

        IF v_cupos IS NULL OR v_cupos <= 0 THEN
            RAISE_APPLICATION_ERROR(
                -20023,
                'El viaje no tiene cupos disponibles'
            );
        END IF;

    ELSIF :NEW.estado = 'Cancelada' THEN
        IF v_estado_viaje <> 'Cancelado' THEN
            IF v_salida IS NULL
               OR SYSDATE > v_salida - (2 / 24) THEN
                RAISE_APPLICATION_ERROR(
                    -20024,
                    'La solicitud solo puede cancelarse con al menos 2 horas de anticipacion'
                );
            END IF;
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_solicitud_cupos
AFTER UPDATE OF estado ON solicitud
FOR EACH ROW
BEGIN
    IF :OLD.estado <> 'Aceptada'
       AND :NEW.estado = 'Aceptada' THEN
        UPDATE viaje
           SET cuposdisponibles = cuposdisponibles - 1
         WHERE idviaje = :NEW.idviaje;

    ELSIF :OLD.estado = 'Aceptada'
       AND :NEW.estado <> 'Aceptada' THEN
        UPDATE viaje
           SET cuposdisponibles = cuposdisponibles + 1
         WHERE idviaje = :NEW.idviaje;
    END IF;
END;
/
