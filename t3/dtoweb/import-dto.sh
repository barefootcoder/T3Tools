#!/bin/sh

# --ignore will "preserve" existing records

/usr/bin/mysqlimport --fields-terminated-by='\t' \
--lines-terminated-by='\n' \
-c fname,lname,company,address1,address2,city,state,zip,phone1,phone2,email \
-h jupiter \
-u gregg \
-px00foo \
-v  --replace \
webdb phonelist.txt
