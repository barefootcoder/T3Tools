use timer
go
-----------------------------------------------------------
-- Initial setup.

--Default settings (1.0/100% modifier), starting in 4Q.

-- emp, comm_type, pay_type, modifier, start_date, end_date 
insert commission_modifier
select emp, "A" , "E", 1.00, "10/1/1999", "12/31/9999" 
from employee
union
select emp, "E" , "E", 1.00, "10/1/1999", "12/31/9999" 
from employee
union
select salesman, "A" , "E", 1.00, "10/1/1999", "12/31/9999" 
from salesman
union
select salesman, "E" , "E", 1.00, "10/1/1999", "12/31/9999" 
from salesman

-----------------------------------------------------------

--Update 4Q settings for non-1.0 adjusters.
--Emp 139: Wayne Loy 1.1
--Emp 132: Chris Weber 1.1
--Emp 101: Buddy 1.1
--Emp 134: Christy 1.15
--Emp 112: Marcus .95
--Emp 112: Chip .85

--Emp 139: Wayne Loy
--Emp 132: Chris Weber
--Emp 101: Buddy
--Update 4Q settings for non-1.0 adjusters.
update commission_modifier
set modifier = 1.10
where emp in ( "132" , "101", "139" )

--Emp 134: Christy
--Update 4Q settings for non-1.0 adjusters.
update commission_modifier
set modifier = 1.15
where emp in ( "134" )

--Emp 112: Marcus
--Update 4Q settings for non-1.0 adjusters.
update commission_modifier
set modifier = .95
where emp in ( "112" )

--Emp 112: Chip
--Update 4Q settings for non-1.0 adjusters.
update commission_modifier
set modifier = .85
where emp in ( "107" )

-------------------------------------------
--1Q Adjustments
-- None
-------------------------------------------

-------------------------------------------
--2Q Adjustments
--Emp 139: Wayne Loy 1.15
--Emp 136: Mike W 1.05
--Emp 132: Chris Weber 1.05
--Emp 134: Christy 1.10

-- Term old modifiers.
update commission_modifier
set  end_date = "3/31/00"
where emp in ( "139","136","132","134","125" )
and end_date = "12/31/9999"

insert commission_modifier values ( "139", "E", "E", 1.15, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "139", "A", "E", 1.15, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "136", "E", "E", 1.05, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "136", "A", "E", 1.05, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "132", "E", "E", 1.05, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "132", "A", "E", 1.05, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "134", "E", "E", 1.10, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "134", "A", "E", 1.10, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "125", "E", "E", 1.05, "4/1/00", "12/31/9999" )
insert commission_modifier values ( "125", "A", "E", 1.05, "4/1/00", "12/31/9999" )

-- emp, comm_type, pay_type, modifier, start_date, end_date 
go


