use webdb;
alter table phonelist add city varchar(50) after address2;
alter table phonelist add state varchar(50) after city;
alter table phonelist add zip char(5) after state;
