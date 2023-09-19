DELIMITER $$
CREATE PROCEDURE `sp_discharge_CreateLog`(
In_patientId varchar(50),
In_message  varchar(4000),
In_createdBy varchar(50)
)
begin
insert into log_dischargeprocess(patientId, message, created_on,  created_by)
values(In_patientId,In_message,  now(), In_createdBy);
end$$
DELIMITER ;
