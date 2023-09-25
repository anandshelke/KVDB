drop procedure sp_UpdateInvoiceType;

DELIMITER $$
CREATE DEFINER=`dbuser`@`%` PROCEDURE `sp_UpdateInvoiceType`(
in_invoiceId VARCHAR(50)
)
BEGIN
	declare _invoiceType varchar(50);
    -- declare _monthlyCount integer default 0;
 -- This procedure is similar to getInvoiceType. 
 -- THE DEPENDENCY QUERY DOES NOT SHOW getInvoiceType FUNCTION BEING USED FROM ANY SP SO IT MAY BE REPLACED COMPLETELY BY this sp_UpdateInvoiceType procedure
 -- First check if the invoice has monthly charges. If so, it is called Monthly invoice and no other type is checked
 -- If it is not a monthly invoice, check if it a Refund invoice and set type to Refund
 -- If it is neither monthly nor refund it is called Other invoice as used elsewhere in the system

-- 2023-26 made multiple changes.
declare _cntMonthlyCharges, _cntChargeTypes integer default 0;
declare _chargeDescription varchar(50);
    
-- Check if it a invoice for consumables
select count(*) into _cntMonthlyCharges from invoicedetail 
where invoiceid  =  in_invoiceId 
and chargeDescription in('Monthly Advance - ADM','Monthly Advance');

-- Setting the invoice type to 'Other' by default which is generic type. If the invoice belongs to any specific type, 
-- it should be set subseuquently in the procedure
set _invoiceType = 'Other'; -- 2023-26

if _cntMonthlyCharges > 0 then 
	set _invoiceType = 'Monthly';
end if;

if  instr(in_invoiceId, "Ref") > 0 then  -- Check if it is a refund invoice
	set _invoiceType = 'Refund';
end if;

-- Check if the invoice is a Physiotherapy or discount  invoice
-- A Physio invoice has only Physio charges. Discount invoice is a one which has only discount charges
-- However Physio invoice can have discount charge and still remain Physio invoice
-- 2023-26
-- Check only for Physio + Discount or any other charge in future + Discount
		select count(distinct(chargeDescription)) into _cntChargeTypes from invoicedetail where invoiceid = in_invoiceId and chargeDescription <> 'Invoice discount'; 
			   
		-- If there is only 1 type of charges, check if these are physio charges
		if _cntChargeTypes = 1 then
			select distinct(chargeDescription) into _chargeDescription from invoicedetail 
			where invoiceid = in_invoiceId and chargeDescription <> 'Invoice discount'; 

			if strcmp(_chargeDescription, 'Physiotherapy') = 0 then 
				set _invoiceType = 'Physiotherapy';
			end if;
		end if;
-- end of check for Physio or any other charge(future) + Discount

-- Check for invoice that has single type of charges. If there is only 1 type of charges, check if these are physio or discount charges
select count(distinct(chargeDescription)) into _cntChargeTypes from invoicedetail where invoiceid = in_invoiceId ; 
        
 if _cntChargeTypes = 1 then
	select distinct(chargeDescription) into _chargeDescription from invoicedetail where invoiceid = in_invoiceId; 

	if strcmp(_chargeDescription, 'Physiotherapy') = 0 then 
		set _invoiceType = 'Physiotherapy';
	elseif strcmp(_chargeDescription, 'Invoice discount') = 0 then -- 2023-19
		set _invoiceType = 'Discount';
	elseif strcmp(_chargeDescription, 'Monthly Advance - ADM') or  strcmp(_chargeDescription, 'Monthly Advance')  = 0 then
		set _invoiceType = 'Monthly';
	else
		set _invoiceType = 'Other';
	end if;
end if;

Update invoicemaster set invoiceType = _invoiceType where  invoiceid = in_invoiceId;
 
END$$
DELIMITER ;
