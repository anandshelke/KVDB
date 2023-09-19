DELIMITER $$
CREATE  PROCEDURE `sp_discharge_createRefundInvoice`(
In In_patientId varchar(50),
In In_invoiceAmount double
)
BEGIN
declare _userLocation  varchar(50);
declare _result varchar(4000);

select userlocation into _userLocation from patientmaster where patientId = In_patientId;

call sp_CreateInvoice(In_patientId, 'System Refund', _userLocation, now(), now(), 'Discharge - Created for refund. ', @out_invoiceId);
call sp_CreateInvoiceDetail(@out_invoiceId,'Refund',null, null,  1, In_invoiceAmount, 'Discharge - Created for refund. ','Discharge - Created for refund. ', now(), 'sp_discharge_createRefundInvoice');

call sp_UpdateInvoiceParams(@out_invoiceId);

call sp_discharge_CreateLog(In_patientId, concat('Refund invoice of Rs.',cast(In_invoiceAmount as char), ' created for patient ', In_patientId), 'Discharge Preparation');

-- Updating the advance payment to have balance as 0 since all such advance payments are converted to refunds
-- It is important to keep the remarks column before balance column in the update as the pre-update value of balance is used in remarks
-- If it is kept before remarks column, the balance in the remarks is updated as 0
update advancepayment 
set 
remarks = concat(ifnull(remarks,''), '. ', now(), ' - ','Updated to 0 from  - ', cast(balance as char), ' during discharge refund process'),
balance = 0,
lastmodified_by  = 'sp_discharge_createRefundInvoice',
lastmodified_on  = now()
where patientid = In_patientId and balance > 0 ;

END$$
DELIMITER ;
