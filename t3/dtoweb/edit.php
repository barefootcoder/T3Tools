<head> 
<link rel="stylesheet" href="phonedb.css">
</head>
<body>

Add a record: <form action="change.php" method="post">
<table>
	<tr>
		<td>	First Name: </td>
		<td>
<?php
print"<input type='text' name='fname' value='$fname' width=20 size=20 length=20>";
?>
		</td>
	</tr>
	<tr>
		<td>	Last Name: </td>
		<td>
<?php
print"<input type='text' name='lname' value='$lname' width=20 size=20 length=20>";
?>
		</td>
	</tr>
	<tr>
		<td>	Company: </td>
		<td>
<?php
print"<input type='text' name='company' value='". urldecode($company) . "' width=20 size=20 length=20>";
?>
		</td>
	</tr>
	<tr>
<td> Address 1: </td>
		<td>
<?php
print"<input type='text' name='address1' value='". urldecode($address1) . "' width=20 size=20 length=20>";
?>
		</td>
	</tr>
	<tr>
<td>Address 2:</td>
	<td>
<?php
print"<input type='text' name='address2' value='". urldecode($address2) . "' width=20 size=20 length=20>";
?>
	</td>
	</tr>
	<tr>
<td>City:</td>
	<td>
<?php
print"<input type='text' name='address2' value='". urldecode($city) . "' width=20 size=20 length=20>";
?>
	</td>
	</tr>
	<tr>
<td>State:</td>
	<td>
<?php
print"<input type='text' name='address2' value='". urldecode($state) . "' width=20 size=20 length=20>";
?>
	</td>
	</tr>
	<tr>
<td>Zip:</td>
	<td>
<?php
print"<input type='text' name='address2' value='". urldecode($zip) . "' width=20 size=20 length=20>";
?>
	</td>
	</tr>
	<tr>
<td>Phone 1: (primary)</td>
	<td>
<?php
print"<input type='text' name='phone1' value='$phone1' width=10 size=10 length=10>";
?>
(no spaces, dashes, parens, or other stuff)
	</td>
	</tr>
	<tr>
<td>Phone 2: (secondary)</td>
	<td>
<?php
print"<input type='text' name='phone2' value='$phone2' width=10 size=10 length=10>";
?>
(no spaces, dashes, parens, or other stuff)
	</td>
	</tr>
	<tr>
<td>Email:</td>
	<td>
<?php
print"<input type='text' name='email' value='$email' width=20 size=20 length=20>";
?>
	</td>
	</tr>
	<tr>
<td>Other (have fun):</td>
	<td>
<?php
print"<textarea wrap='virtual' cols=30 rows=5 name='other'>" . urldecode($other). "</textarea>";
?>
	</td>
	</tr>
</table>
<?php
print"<input type=hidden name=recid value='$recid'>";
?>
<input type=submit value="Update Database" class="sbttn">
<p>
