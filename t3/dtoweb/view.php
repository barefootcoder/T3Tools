<?php
	require "daytimer-conf.inc";
	// make it look pretty!
	 print("<head> 
	     <link rel=\"stylesheet\" href=\"phonedb.css\">
		 </head>
		 <body>");

    $link = mysql_connect("$dbhost", "$dbuser", "$dbpass")
        or die ("Could not connect");
    mysql_select_db ("webdb")
        or die ("Could not select database");
    
$query = "SELECT recid,fname,lname,company,address1,address2,city,state,zip,phone1,phone2,email,other FROM
phonelist where recid = $recid";
    $result = mysql_query ($query)
        or die ("Query failed");


	// access things by name. easier, I think.
	$fields = mysql_fetch_array($result);
	print"Name: ". $fields["fname"] . " " .  $fields["lname"] . "<br>";
	print"Phone: " . $fields["phone1"] . "<br>";
	print"Other phone: " .  $fields["phone2"] . "<br>";
	print"Company: " .  $fields["company"] . "<br>";
	print"Address: " .  $fields["address1"] . "<br>";
	print"Address: " . $fields["address2"] . "<br>";
	print"City: " . $fields["city"] . "<br>";
	print"State: " . $fields["state"] . "<br>";
	print"Zip: " . $fields["zip"] . "<br>";
	print"Email address: " . $fields["email"] . "<br>";
	print"Comment: " . $fields["other"] . "<br>";

    mysql_close($link);

	print"<p>";
	print"<form name='edit' action='edit.php' method='post'>";
	print"<input type=hidden value=" . $fields["fname"] . " name=fname>";
	print"<input type=hidden value=" . $fields["lname"] . " name=lname>";
	print"<input type=hidden value=" . $fields["phone1"] . " name=phone1>";
	print"<input type=hidden value=" . $fields["phone2"] . " name=phone2>";
	print"<input type=hidden value=" . urlencode($fields["company"]) . " name=company>";
	print"<input type=hidden value=" . urlencode($fields["address1"]) . " name=address1>";
	print"<input type=hidden value=" . urlencode($fields["address2"]) . " name=address2>";
	print"<input type=hidden value=" . urlencode($fields["city"]) . " name=city>";
	print"<input type=hidden value=" . urlencode($fields["state"]) . " name=state>";
	print"<input type=hidden value=" . urlencode($fields["zip"]) . " name=zip>";
	print"<input type=hidden value=" . $fields["email"] . " name=email>";
	print"<input type=hidden value=" . urlencode($fields["other"]) . " name=other>";
	print"<input type=hidden name=recid value='" . $recid . "'>";
	print"<input type=submit value='Edit this record' class='sbttn'>";

?>


