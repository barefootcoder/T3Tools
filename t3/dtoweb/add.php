<?php
	require "daytimer-conf.inc";
    $link = mysql_connect("$dbhost", "$dbuser", "$dbpass")
        or die ("Could not connect");
//    print ("Connected successfully");
    mysql_select_db ("webdb")
        or die ("Could not select database");
    
print("fname is $fname<p> lname is $lname<p> company is $company<p> address is $address1<p> address2 is
$address2<p> phone 1 is $phone1<p> phone 2 is $phone2<p> email is $email<p> and other is
$other");
print("<p>");

$query = "INSERT INTO phonelist VALUES 
('','$fname','$lname','$company','$address1','$address2','$city','$state','$zip','$phone1','$phone2','$email','$other')";

$result = mysql_query ($query) or die ("Query failed");

	// printing HTML result

	print("Data inserted. Have a nice day.\n");
    
    mysql_close($link);
?>


