CREATE OR REPLACE TRIGGER trg_viaje_insert
BEFORE INSERT ON viaje
FOR EACH ROW
BEGIN
    IF :NEW.estado <> 'Programado' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Un viaje nuevo debe crearse en estado Programado');
    END IF;
    IF :NEW.fechasalida <= SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20002, 'La fecha de salida debe ser futura');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_viaje_cupos
BEFORE INSERT OR UPDATE OF cuposdisponibles, placa ON viaje
FOR EACH ROW
DECLARE
    v_cupos vehiculo.cupos%TYPE;
BEGIN
    SELECT cupos INTO v_cupos FROM vehiculo WHERE placa = :NEW.placa;
    IF :NEW.cuposdisponibles > v_cupos THEN
        RAISE_APPLICATION_ERROR(-20003, 'Los cupos del viaje no pueden superar los cupos del vehiculo');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
END;
/

CREATE OR REPLACE TRIGGER trg_viaje_estado
FOR UPDATE OF estado ON viaje
COMPOUND TRIGGER
    TYPE t_ids IS TABLE OF viaje.idviaje%TYPE;
    g_cancelados t_ids := t_ids();

    BEFORE EACH ROW IS
    BEGIN
        IF :OLD.estado = :NEW.estado THEN
            NULL;
        ELSIF :OLD.estado IN ('Completado', 'Cancelado') THEN
            RAISE_APPLICATION_ERROR(-20004, 'No se puede modificar el estado de un viaje completado o cancelado');
        ELSIF :OLD.estado = 'Programado' AND :NEW.estado = 'En curso' THEN
            NULL;
        ELSIF :OLD.estado = 'En curso' AND :NEW.estado = 'Completado' THEN
            IF :NEW.fechallegada IS NULL THEN
                :NEW.fechallegada := SYSDATE;
            END IF;
        ELSIF :NEW.estado = 'Cancelado' AND :OLD.estado IN ('Programado', 'En curso') THEN
            IF SYSDATE > :OLD.fechasalida - 2 / 24 THEN
                RAISE_APPLICATION_ERROR(-20005, 'El viaje solo puede cancelarse con al menos 2 horas de anticipacion');
            END IF;
        ELSE
            RAISE_APPLICATION_ERROR(-20006, 'Transicion de estado invalida');
        END IF;
    END BEFORE EACH ROW;

    AFTER EACH ROW IS
    BEGIN
        IF :NEW.estado = 'Cancelado' AND :OLD.estado <> 'Cancelado' THEN
            g_cancelados.EXTEND;
            g_cancelados(g_cancelados.LAST) := :NEW.idviaje;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FOR i IN 1 .. g_cancelados.COUNT LOOP
            UPDATE solicitud
            SET estado = 'Cancelada'
            WHERE idviaje = g_cancelados(i)
              AND estado IN ('Pendiente', 'Aceptada');
        END LOOP;
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
    IF :NEW.estado <> 'Pendiente' THEN
        RAISE_APPLICATION_ERROR(-20010, 'Una solicitud nueva debe crearse en estado Pendiente');
    END IF;
    SELECT v.estado, v.cuposdisponibles, ve.documentoconductor
    INTO v_estado, v_cupos, v_conductor
    FROM viaje v
    JOIN vehiculo ve ON ve.placa = v.placa
    WHERE v.idviaje = :NEW.idviaje;
    IF v_estado <> 'Programado' THEN
        RAISE_APPLICATION_ERROR(-20011, 'Solo se puede solicitar cupo en viajes programados');
    END IF;
    IF v_cupos <= 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'El viaje no tiene cupos disponibles');
    END IF;
    IF v_conductor = :NEW.documentopasajero THEN
        RAISE_APPLICATION_ERROR(-20013, 'El conductor no puede solicitar cupo en su propio viaje');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL;
END;
/

CREATE OR REPLACE TRIGGER trg_solicitud_estado
BEFORE UPDATE OF estado ON solicitud
FOR EACH ROW
DECLARE
    v_estado viaje.estado%TYPE;
    v_cupos  viaje.cuposdisponibles%TYPE;
    v_salida viaje.fechasalida%TYPE;
BEGIN
    IF :OLD.estado = :NEW.estado THEN
        RETURN;
    END IF;
    IF :OLD.estado IN ('Rechazada', 'Cancelada') THEN
        RAISE_APPLICATION_ERROR(-20020, 'No se puede modificar una solicitud rechazada o cancelada');
    END IF;
    IF :OLD.estado = 'Aceptada' AND :NEW.estado <> 'Cancelada' THEN
        RAISE_APPLICATION_ERROR(-20021, 'Una solicitud aceptada solo puede cancelarse');
    END IF;
    SELECT estado, cuposdisponibles, fechasalida
    INTO v_estado, v_cupos, v_salida
    FROM viaje
    WHERE idviaje = :NEW.idviaje;
    IF :NEW.estado = 'Aceptada' THEN
        IF v_estado <> 'Programado' THEN
            RAISE_APPLICATION_ERROR(-20022, 'Solo se pueden aceptar solicitudes de viajes programados');
        END IF;
        IF v_cupos <= 0 THEN
            RAISE_APPLICATION_ERROR(-20023, 'El viaje no tiene cupos disponibles');
        END IF;
    ELSIF :NEW.estado = 'Cancelada' THEN
        IF SYSDATE > v_salida - 2 / 24 THEN
            RAISE_APPLICATION_ERROR(-20024, 'La solicitud solo puede cancelarse con al menos 2 horas de anticipacion');
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_solicitud_cupos
AFTER UPDATE OF estado ON solicitud
FOR EACH ROW
BEGIN
    IF :OLD.estado <> 'Aceptada' AND :NEW.estado = 'Aceptada' THEN
        UPDATE viaje SET cuposdisponibles = cuposdisponibles - 1 WHERE idviaje = :NEW.idviaje;
    ELSIF :OLD.estado = 'Aceptada' AND :NEW.estado <> 'Aceptada' THEN
        UPDATE viaje SET cuposdisponibles = cuposdisponibles + 1 WHERE idviaje = :NEW.idviaje;
    END IF;
END;
/
