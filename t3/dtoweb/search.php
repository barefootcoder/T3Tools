<?php
	require "daytimer-conf.inc";
	// do that funky shee-it
	print("<head> 
	<link rel=\"stylesheet\" href=\"phonedb.css\">
	</head>
	<body>");

    $link = mysql_connect("$dbhost", "$dbuser", "$dbpass")
        or die ("Could not connect");
//    print ("Connected successfully");
    mysql_select_db ("webdb")
        or die ("Could not select database");
    
#$query = "SELECT recid,fname,lname,company,address1,address2,city,state,zip,phone1,phone2,email,other FROM phonelist where fname || lname like
	#'%$searchname%'";
$query = "SELECT recid,fname,lname,company 
FROM phonelist 
WHERE fname || lname like '%$searchname%'
ORDER BY lname
";
    $result = mysql_query ($query)
        or die ("Query failed");

	// printing HTML result

	$hits = mysql_num_rows($result);
	print("Got $hits returns<p>");
	print("Search returned:<p>");
	for($i = 0; $i <= $hits; $i++)
	{
	list($recid,$fname,$lname,$company) = mysql_fetch_row($result);
	#list($recid,$fname,$lname,$company,$phone1,$phone2,$address1,$address2,$email,$other) =
		if($lname)
		{
			print("<a href='view.php?recid=$recid'>$fname $lname</a><br>");
		} else
		{
			print("<a href='view.php?recid=$recid'>$company</a><br>");
		}
	}
    mysql_close($link);
?>


