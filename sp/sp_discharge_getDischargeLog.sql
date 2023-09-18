DELIMITER $$
CREATE DEFINER=`anand`@`localhost` PROCEDURE `sp_discharge_getDischargeLog`(
In_patientId varchar(50)
)
begin
	select * from log_dischargeprocess where patientid = In_patientId order by created_on desc; 
end$$
DELIMITER ;
