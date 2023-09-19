DELIMITER $$
CREATE PROCEDURE `sp_discharge_summary`(
In In_patientId varchar(50)
)
BEGIN
declare _totalInvoiceAmount, _totalUnpaidAmount, _totalPaidAmount, _totalPaymentReceived, _totalBalanceFromAdvancePayment, _depositCharges, _totalDepositSettled double default 0;
declare _invoiceStatus varchar(20);
declare _showRefund boolean default false; 
declare _cnt int;

select ifnull(sum(invoiceamount),0) , ifnull(sum(balanceamount),0) into _totalInvoiceAmount, _totalUnpaidAmount from invoicemaster where patientid = In_patientId;
select ifnull(sum(paymentamount),0) into _totalPaidAmount from invoicepayment where invoiceid in (select invoiceid from invoicemaster where patientid = In_patientId);
select ifnull(sum(paymentAmount),0), ifnull(sum(balance),0) into _totalPaymentReceived, _totalBalanceFromAdvancePayment from advancepayment where patientid = In_patientId;
select ifnull(depositcharges,0) into _depositCharges from patientmaster where patientid = In_patientId;
select ifnull((paymentamount - balance),0)  into _totalDepositSettled from advancepayment where patientid = In_patientId and paymentmode= 'Deposit';

-- Flag that decide if Refund button should be shown on the UI
-- Only if all the invoices are paid, refund button should be shown
set _showRefund = false;
select count(distinct invoiceStatus) into _cnt from invoicemaster where patientid = In_patientId;
if (_cnt = 1) then	
	select distinct invoiceStatus into _invoiceStatus from invoicemaster where patientid = In_patientId;

	if _invoiceStatus = 'Paid' and _totalBalanceFromAdvancePayment > 0 then
		set _showRefund = true;
	end if; 
end if;

Select _totalInvoiceAmount, _totalUnpaidAmount, _totalPaidAmount, _totalPaymentReceived, _totalBalanceFromAdvancePayment, _depositCharges, _totalDepositSettled,_showRefund;
END$$
DELIMITER ;
