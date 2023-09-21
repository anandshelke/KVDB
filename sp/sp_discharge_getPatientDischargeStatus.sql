drop procedure sp_discharge_getPatientDischargeStatus;

call sp_discharge_getPatientDischargeStatus('KV-Kothrud-53');


DELIMITER $$
CREATE PROCEDURE `sp_discharge_getPatientDischargeStatus`(
IN in_patientId varchar(50) 
)
BEGIN
declare _isDischarged boolean default false; 
declare _dischargeDate date; 
declare _cnt integer default 0;

select count(*) into _cnt from patientmarkeddischarge where patientId = in_patientId;
if _cnt = 1 then
	select true, patientDischargeDate into _isDischarged, _dischargeDate  from patientmarkeddischarge where patientid = in_patientId;
end if;

select count(*) into _cnt from patientdischarge where patientId = in_patientId;
if _cnt = 1 then
	select true, patientDischargeDate into _isDischarged, _dischargeDate from patientdischarge where patientid = in_patientId;
end if;

select _isDischarged, _dischargeDate;

END$$
DELIMITER ;