DELIMITER $$
CREATE DEFINER=`anand`@`localhost` PROCEDURE `sp_discharge_Prepare`(
In In_patientId varchar(50),
In In_DischargeDate date
)
Begin

declare _dailyStayCharges, _depositCharges, _monthlyAdvanceAmount, _advanceAmount, _amountPaid, _newMonthlyAdvanceAmount double;
declare _monthlyInvoiceFromDate, _monthlyInvoiceTodate date;
declare _admissionDate date;
declare _daysElapsed, _daysLeft INT;
declare _monthlyInvoiceId, _monthlyInvoiceStatus varchar(50);
declare _firstMonthDischarge boolean default false; -- 2023-bug-4


-- declare _cntMonthlyPaidInvoice, _MonthlyInvoiceCreated, _MonthlyInvoicePaid INT default 0;    
-- declare _balancedMonthlyAdvance, _totalBalanceAmount, _unPaidInvoiceAmount, _newMonthlyAdvanceAmount, PartiallyPaidMonthlyAdvance  double;
-- declare _admRegAmount double;
-- declare _userLocation,_monthlyInvoiceId varchar(50);
-- declare _firstMonthDischarge boolean default false; -- 2023-bug-4
-- declare _remainingBalance double default 0; -- 2023-bug-5


-- mark the patient for discharge
call sp_discharge_MarkPatientForDischarge(In_patientId,In_DischargeDate );


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
if In_DischargeDate not between _monthlyInvoiceFromDate and _monthlyInvoiceTodate then
	call sp_discharge_CreateLog(In_patientId, 'LOG','No Recent Monthly Invoice Foundfor the current period. Raise current Monthly Invoice', 'Discharge Preparation');
else
-- Calculated days elapsed (spent) and days left
-- For this date calculation check the admission and discharge month to count correct days elapsed
if (month(_admissionDate) = month(In_DischargeDate) AND year(_admissionDate) = year(In_DischargeDate)) then
	SELECT DATEDIFF(In_DischargeDate, _admissionDate) + 1, DATEDIFF(_monthlyInvoiceTodate, In_DischargeDate) INTO _daysElapsed , _daysLeft;  
	set _firstMonthDischarge  = true; -- 2023-bug-4
else
	set _firstMonthDischarge  = false; -- 2023-bug-
	select DATEDIFF(In_DischargeDate, _monthlyInvoiceFromDate) + 1, DATEDIFF(_monthlyInvoiceTodate, In_DischargeDate) INTO _daysElapsed , _daysLeft ;
end if;

call sp_discharge_CreateLog(In_patientId, 'LOG',concat('Number of stay days =',cast(_daysElapsed as char), ' and days remaining =', cast(_daysLeft as char)), 'Discharge Preparation');

-- calculate updated montly invoice amount based on the discharge date
set _newMonthlyAdvanceAmount =  _monthlyAdvanceAmount - (_daysElapsed * _dailyStayCharges);
call sp_discharge_CreateLog(In_patientId, 'LOG',concat('Adjusted monthly amount =',cast(_newMonthlyAdvanceAmount as char)), 'Discharge Preparation');
   
-- Update monthly invoice based on days and daily stay charges 
update invoicemaster 
set invoiceamount = _newMonthlyAdvanceAmount, invocieToDate = In_DischargeDate, balance = _newMonthlyAdvanceAmount -_amountPaid,
notes = concat(notes, '. ', now(), ' - ','Adjusted amount and date for monthly invoice - ', _monthlyInvoiceId,' during discharge process')
where  patientid = In_patientId and invoiceid = _monthlyInvoiceId;

-- update ToDate of all other and physio invoices to the DoD 
-- We need to update correct forenightly invoices hence In_DischargeDate < invoiceToDate;
Update invoicemaster set invoicetodate = In_DischargeDate, notes = concat(notes, '. ', now(), ' - ','Adjusted invoice ToDate during discharge process')
where patientid = In_patientId and 
In_DischargeDate >= invoiceFromDate and In_DischargeDate < invoiceToDate;

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

-- create deposit amount as advance payment record do that it is available for settlement of invoices
select depositCharges into _depositCharges from patientmaster where patientid = In_patientId;

if _depositCharges > 0 then 
	call sp_CreateAdvancePayment(In_patientId, null, 'Discharge',_depositCharges, curdate(),null,null,null,null,null,null,'Discharge', 'Created from deposit charged for settlement', 'sp_discharge_Prepare');
	call sp_discharge_CreateLog(In_patientId, 'LOG',concat('Advance payment created from Deposit amount of Rs.',cast(_depositCharges as char)), 'Discharge Preparation');
end if;


end if;





END$$
DELIMITER ;
