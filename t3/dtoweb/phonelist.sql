use webdb;
drop table if exists phonelist;
create table phonelist
(
	recid int not null auto_increment primary key,
	fname VARCHAR(50) not null ,
	lname VARCHAR(50),
	company VARCHAR(75),
	address1 VARCHAR(75),
	address2 VARCHAR(75),
	city VARCHAR(50),
	state VARCHAR(25),
	zip VARCHAR(5),
	phone1 VARCHAR(10),
	phone2 VARCHAR(10),
	email VARCHAR(50),
	other TEXT
);
