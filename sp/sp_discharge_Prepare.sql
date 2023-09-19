DELIMITER $$
CREATE PROCEDURE `sp_discharge_Prepare`(
In In_patientId varchar(50),
In In_DischargeDate varchar(30)
)
Begin

declare _dailyStayCharges, _depositCharges, _monthlyAdvanceAmount, _amountPaid double;
declare  _advanceAmount double default 0;
declare _newMonthlyAdvanceAmount double default 0;
declare _monthlyInvoiceFromDate, _monthlyInvoiceTodate date;
declare _admissionDate date;
declare _daysElapsed, _daysLeft INT;
declare _monthlyInvoiceId, _monthlyInvoiceStatus varchar(50);
declare _firstMonthDischarge boolean default false; -- 2023-bug-4

declare _dischargeDate varchar(30);

call sp_discharge_CreateLog(In_patientId, 'Start of the discharge process', 'Discharge Preparation');

set _dischargeDate = str_to_date(In_DischargeDate,'%Y-%m-%d');
select depositCharges,  monthlyStayCharges into _depositCharges, _dailyStayCharges from patientmaster where patientid = In_patientId;


-- mark the patient for discharge
call sp_discharge_MarkPatientForDischarge(In_patientId,_dischargeDate );

-- Get all the invoices for the patient updated
call sp_UpdatePateintInvoiceParams(In_patientId);

-- Get latest monthly invoice generated for the patient
-- Admission and Registration are one time and non refundable and hence not considered
-- deposit is refundable and has to be taken separatey for settlement record and transparency
select im.invoicefromdate , im.invoicetodate, im.invoiceId, id.chargeAmount, im.invoicestatus
into _monthlyInvoiceFromDate, _monthlyInvoiceTodate, _monthlyInvoiceId, _monthlyAdvanceAmount, _monthlyInvoiceStatus
from invoicemaster im
inner join invoicedetail id on im.invoiceid = id.invoiceid
where im.patientid = In_patientId  and
id.chargedescription like 'Monthly Advance%'  
order by invoicetodate desc limit 1;

-- get the payment made for the monthly invoice
select sum(paymentAmount) into _amountPaid from invoicepayment where invoiceid = _monthlyInvoiceId;

-- Check if the recent monthly invoice is raised
if _dischargeDate not between _monthlyInvoiceFromDate and _monthlyInvoiceTodate then
	call sp_discharge_CreateLog(In_patientId,'No Recent Monthly Invoice found for the current period. Raise current Monthly Invoice', 'Discharge Preparation');
else
-- Calculated days elapsed (spent) and days left
-- For this date calculation check the admission and discharge month to count correct days elapsed
if (month(_admissionDate) = month(_dischargeDate) AND year(_admissionDate) = year(_dischargeDate)) then
	SELECT DATEDIFF(_dischargeDate, _admissionDate) + 1, DATEDIFF(_monthlyInvoiceTodate, _dischargeDate) INTO _daysElapsed , _daysLeft;  
	set _firstMonthDischarge  = true; -- 2023-bug-4
else
	set _firstMonthDischarge  = false; -- 2023-bug-
	select DATEDIFF(_dischargeDate, _monthlyInvoiceFromDate) + 1, DATEDIFF(_monthlyInvoiceTodate, _dischargeDate) INTO _daysElapsed , _daysLeft ;
end if;

call sp_discharge_CreateLog(In_patientId, concat('Number of stay days =',cast(_daysElapsed as char), ' and days remaining =', cast(_daysLeft as char)), 'Discharge Preparation');

-- calculate updated montly invoice amount based on the discharge date
set _newMonthlyAdvanceAmount =  _monthlyAdvanceAmount - (_daysElapsed * _dailyStayCharges);

call sp_discharge_CreateLog(In_patientId, concat('Adjusted monthly amount ',cast(_newMonthlyAdvanceAmount as char)), 'Discharge Preparation');
   
-- Update monthly invoice based on days and daily stay charges 
update invoicemaster 
set invoiceamount = _newMonthlyAdvanceAmount, invoiceToDate = _dischargeDate, balanceAmount = _newMonthlyAdvanceAmount -_amountPaid,
notes = concat(notes, '. ', now(), ' - ','Adjusted amount and date for monthly invoice - ', _monthlyInvoiceId,' during discharge process')
where  patientid = In_patientId and invoiceid = _monthlyInvoiceId;

call sp_discharge_CreateLog(In_patientId, concat('Updated invoice  amount of monthly invoice  ',_monthlyInvoiceId, 'to ', cast(_newMonthlyAdvanceAmount as char)), 'Discharge Preparation');
call sp_discharge_CreateLog(In_patientId, concat('Updated To Date of monthly invoice ',_monthlyInvoiceId, 'to ', cast(_dischargeDate as char)), 'Discharge Preparation');

-- update ToDate of all other and physio invoices to the DoD 
-- We need to update correct forenightly invoices hence _dischargeDate < invoiceToDate;
Update invoicemaster set invoicetodate = _dischargeDate, notes = concat(notes, '. ', now(), ' - ','Adjusted invoice ToDate during discharge process')
where patientid = In_patientId and 
_dischargeDate >= invoiceFromDate and _dischargeDate < invoiceToDate;

call sp_discharge_CreateLog(In_patientId, concat('Updated To Dates of other and physio invoices to ', cast(_dischargeDate as char)), 'Discharge Preparation');

call sp_UpdateInvoiceParams(_monthlyInvoiceId);


-- Create advance payment record if appropriate. This is applicable only for monthly invoices
-- For paid monthlyinvoices, the entire amount is paid so early discharge will always have excess amount for settlement.
if strcmp(_monthlyInvoiceStatus,"Paid") = 0 then
	set _advanceAmount = _amountPaid - _newMonthlyAdvanceAmount;
	call sp_CreateAdvancePayment(In_patientId, _monthlyInvoiceId, 'Discharge',_advanceAmount, curdate(),null,null,null,null,null,null,'Discharge', 'Amount from adjusted paid invoice', 'sp_discharge_Prepare');
end if;

-- For partially paid monthly invoices, need to get the payment made and if it is more than _newMonthlyAdvanceAmount then create adv payment entry.
if strcmp(_monthlyInvoiceStatus,"Partial") = 0 then
	if _amountPaid >  _newMonthlyAdvanceAmount then 
		set _advanceAmount = _amountPaid - _newMonthlyAdvanceAmount;
		call sp_CreateAdvancePayment(In_patientId, _monthlyInvoiceId, 'Discharge',_advanceAmount, curdate(),null,null,null,null,null,null,'Discharge', 'Amount from adjusted partial invoice', 'sp_discharge_Prepare');
	end if;
end if;

call sp_discharge_CreateLog(In_patientId, concat('Created advance payment entry of  ', cast(_advanceAmount as char), ' as advance payment'), 'Discharge Preparation');

-- create deposit amount as advance payment record do that it is available for settlement of invoices
if _depositCharges > 0 then 
	call sp_CreateAdvancePayment(In_patientId, null, 'Deposit',_depositCharges, curdate(),null,null,null,null,null,null,'Discharge', 'Created from deposit charged for settlement', 'sp_discharge_Prepare');
	call sp_discharge_CreateLog(In_patientId, concat('Advance payment created from Deposit amount of Rs.',cast(_depositCharges as char)), 'Discharge Preparation');
else
	call sp_discharge_CreateLog(In_patientId, 'Deposit amount is zero and hence cannot use it for settlement', 'Discharge Preparation');
end if;


end if;


call sp_discharge_CreateLog(In_patientId, 'End of the discharge process', 'Discharge Preparation');


END$$
DELIMITER ;
