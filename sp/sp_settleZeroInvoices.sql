DELIMITER $$
CREATE DEFINER=`anand`@`localhost` PROCEDURE `sp_settleZeroInvoices`(
In In_patientId varchar(50)
)
BEGIN
update invoicemaster set invoicestatus = 'Paid', 
notes = concat(notes, '. ', now(), ' - ',' Marked paid during discharge invoice settlement process')
where patientid = In_patientId and invoiceamount = 0 and invoicestatus = 'Unpaid' ;

END$$
DELIMITER ;
