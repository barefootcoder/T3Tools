<?php
	require "daytimer-conf.inc";
    $link = mysql_connect("$dbhost", "$dbuser", "$dbpass")
        or die ("Could not connect");
//    print ("Connected successfully");
    mysql_select_db ("webdb")
        or die ("Could not select database");
    
print("fname is $fname<p> lname is $lname<p> company is $company<p> address is $address1<p> address2 is
$address2<p> phone 1 is $phone1<p> phone 2 is $phone2<p> email is $email<p> and other is
$other<p> for recid $recid<br>");
print("<p>");

$query = "update phonelist set 
fname='$fname',
lname='$lname',
company='$company',
address1='$address1',
address2='$address2',
city='$city',
state='$state',
zip='$zip',
phone1='$phone1',
phone2='$phone2',
email='$email',
other='$other' where recid='$recid'";

$result = mysql_query ($query) or die ("Query failed");

	// printing HTML result

	print("Data changed. Have a nice day.\n");
    
    mysql_close($link);
?>


