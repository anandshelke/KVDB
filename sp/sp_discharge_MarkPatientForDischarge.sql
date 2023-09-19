DELIMITER $$
CREATE PROCEDURE `sp_discharge_MarkPatientForDischarge`(
  IN In_patientId varchar(50),
  In In_DischargeDate date
)
BEGIN
-- This SP is created based on sp_MarkPatientForDischarge with a change of user specified discharge date
-- Ideally the existing sp_MarkPatientForDischarge should be changed but in that case, it will have impact at UI and API level
-- Also the existsing sp_MarkPatientForDischarge may cease to exist and hence creating  new process

    declare _markedalready Int default 0;     
	
    select count(*) into _markedalready  from patientmarkeddischarge where patientid = In_patientId;
    
    if _markedalready = 0 then
		insert into patientmarkeddischarge values(In_patientId, In_DischargeDate, 'sp_discharge_MarkPatientForDischarge', now(),null,null);
	end if;
    
  
END$$
DELIMITER ;
