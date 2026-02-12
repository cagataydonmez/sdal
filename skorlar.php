<?php

	$winscore = (int)$winscore;

	// Create a Blank File if it doesn't already exist
	if (!file_exists($filename))
	{
		$file=fopen($filename, "w");
		fclose ($file);
	}

	// Read the file in
	$oscores = file ($filename);
	$numreadin = count($oscores);

	// Break out the data into a new 2-d array called $tscores
	for ($i = 0; $i < $numreadin; $i++)
	{
		$g = unserialize($oscores[$i]);
		$tscores[$i][0] = $g[0];
		$tscores[$i][1] = $g[1];
	}

	// Fill in any missing data with none/0
	for ($i = $numreadin; $i < $scoresize; $i++)
	{
		$tscores[$i][0] = 0;
		$tscores[$i][1] = "none";
	}

	// Process the actions	

	// Insert a score/name
	if ($action == "INSERT")
	{

		// Add name to end of list, and sort
		$tscores[$scoresize + 1][0] = $winscore;
		$tscores[$scoresize + 1][1] = $winname;
		rsort ($tscores);

		$file=fopen($filename, "w");

		// Write them out
		for ($i = 0; $i < $scoresize; $i++)
		{
			$st = serialize($tscores[$i]) . "\n";
			fputs($file, $st);
		}

		fclose($file);
	}

	// Clear the list	
	if ($action == "CLEAR")
	{

		$k[0] = 0;
		$k[1] = "none";
		$ser = serialize($k);

		$file=fopen($filename, "w");

		for ($i = 0; $i < $scoresize; $i++)
		{
			$st = $ser . "\n";
			fputs($file, $st);
		}

		fclose($file);
	}

	// Process the OUTPUT options
	if ($viewtype == "HTML")
	{
	  // HTML PAGE CREATED HERE
	  ?>


		<table cellpadding=2 cellspacing=2 border=0 width="152">
		<tr align=center> 
		<th bgcolor="#000033"><font color="#FFFFFF" face="Arial, Helvetica, sans-serif">#</font></th>
		<th bgcolor="#000033"><font color="#FFFFFF" face="Arial, Helvetica, sans-serif">Name</font></th>
		<th bgcolor="#000033"><font color="#FFFFFF" face="Arial, Helvetica, sans-serif">Score</font></th>
		</tr>

   	  <?
	
		for ($i = 0; $i < $scoresize; $i++)
		{
			echo ("<tr bgcolor='#666666' align='center'><td><font size='2' face='Arial, Helvetica, sans-serif'>");
			echo ($i + 1);
			echo ("</font></td><td><font size='2' face='Arial, Helvetica, sans-serif'>");
			echo ($tscores[$i][1]);
			echo ("</font></td><td><font size='2' face='Arial, Helvetica, sans-serif'>");
			echo ($tscores[$i][0]);
			echo ("</font></td></tr>");
		}

  	  ?>
		</table>
	  <?

	}

	// FLASH DATA CREATED HERE
	if ($viewtype == "FLASH")
	{
		for ($i = 0; $i < $scoresize; $i++)
		{
			echo ("isim" . $i . "=");
			echo ($tscores[$i][1]);
			echo ("&skor" . $i . "=");
			echo ($tscores[$i][0]);
			echo ("&");
		}
	}

?>
