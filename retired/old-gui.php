<?php
# --------------------------------------------------------------------------
# Copyright (C) 2010 Edward Fjellskål <edward.fjellskaal@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
# --------------------------------------------------------------------------


// Read in configuration from openfpc.conf. Set this to the instance you want to use
$configfile="/etc/openfpc/openfpc-default.conf";
# --------------------------------------------------------------------------
// Nothing to do below this line.
$debug = 0;
$file = fopen($configfile, "r");
$openfpcver=0.5;

// Save config and users into an array
while ( $line = fgets($file, 200) ) {
	if ( preg_match("/^USER/", "$line")) {
		list ($tmp,$user,$pass) = (explode("=",$line));
		$users["$user"] = $pass;
	}

	if (preg_match("/^[A-Z]/", $line)) {
		list ($configkey,$configval) = (explode("=",$line));
		chop($configval);
		$config["$configkey"] = $configval;
	}
}
fclose($file);

// openfpc Database Settings
$dbhost = "127.0.0.1";
$dbuser = 0;
$dbname = 0;
$dbpass = 0;
//OFPC Queue Daemon Settings
$ofpcuser = 0;
$ofpcpass = 0;

if ($config["SESSION_DB_NAME"]) $dbname = $config["SESSION_DB_NAME"];
if ($config["SESSION_DB_USER"]) $dbuser =  $config["SESSION_DB_USER"] ;
if ($config["SESSION_DB_PASS"]) $dbpass =  $config["SESSION_DB_PASS"] ;
if ($config["SESSION_DB_HOST"]) $dbhost =  $config["SESSION_DB_HOST"] ;
if ($config["GUIUSER"])  $ofpcuser=$config["GUIUSER"]  ;
if ($config["GUIPASS"])  $ofpcpass=$config["GUIPASS"]  ;

// Settings
$maxRows = 100;
$ofpc_client = "openfpc-client";

// Variable Initialization
$op         = sanitize("op");         if (empty($op))         $op = "search";
$ipv        = sanitize("ipv");        if (empty($ipv))        $ipv = "2";
$cxtid      = sanitize("cxtid");      if (empty($cxtid))      $cxtid = "";
$sessp      = sanitize("sessp");      if (empty($sessp))      $sessp = "";
$srcip      = sanitize("srcip");      if (empty($srcip))      $srcip = "";
$dstip      = sanitize("dstip");      if (empty($dstip))      $dstip = "";
$srcport    = sanitize("srcport");    if (empty($srcport))    $srcport = "";
$dstport    = sanitize("dstport");    if (empty($dstport))    $dstport = "";
$start_date = sanitize("start_date"); if (!valdate($start_date)) $start_date = date("Y-m-d 00:00:00");
$end_date   = sanitize("end_date");   if (!valdate($end_date))   $end_date   = date("Y-m-d H:i:s");
$protocol   = sanitize("protocol");   if (empty($protocol))   $protocol = "any";
$logline    = sanitize("logline");    if (empty($logline))    $logline = "NoneSet";
$comment    = sanitize("comment");    if (empty($comment))    $comment = "No Comment";

$out="";

$notsrcip = 0; if (is_not_set($srcip)) $notsrcip = 1;
$notdstip = 0; if (is_not_set($dstip)) $notdstip = 1;
$notsrcport  = 0; if (is_not_set($srcport)) $notsrcport = 1;
$notdstport  = 0; if (is_not_set($dstport)) $notdstport = 1;
if ($notsrcip) $srcip = strip_not($srcip);
if ($notdstip) $dstip = strip_not($dstip);
if ($notsrcport)  $srcport = strip_not($srcport);
if ($notdstport)  $dstport = strip_not($dstport);

// Dump some debug output
if ($debug) {
	print "DEBUG ENABLED: PCAPS will be b0rked in debug mode!<br>";
	print "Version is $openfpcver<br>";
	print "dbuser is $dbuser<br>" ;
	print "dbhost is $dbhost<br>" ;
	print "db is $dbname<br>";
	print "dbpass is $dbpass<br>";
	print "openfpcuser is $ofpcuser<br>";
	print "openfpcpass is $ofpcpass<br>";
}

// OP Director

switch ($op) {

    case "Search connection table":
        $out = mainDisplay();
        $out .= showResults();
        $data = doSessionQuery();
        //pollParse($data);
        break;

    case "Extract pcap":
        $out = mainDisplay();
        //$data = doSessionQuery();
        $out .= extractPcapFromSearch();	
        //pollParse($data);
        break;
       
    case "dump":
        $out = mainDisplay();
        $out .= extractPcapFromSession();
        #$out .= showResults();
        #$out = dumpDisplay();   
        break;
        
    case "Store pcap form event":
        $out = mainDisplay();
        $out .= extractPcapFromLog("store");
        break;

    case "Fetch pcap from event":
        $out = mainDisplay();
        $out .= extractPcapFromLog("fetch");
        break;

    default:
        $out = mainDisplay();
        break;
}

echo mainHeading() . $out . mainFooting();

// Operational Functions

function mainDisplay() {
    global $config, $major, $minor, $build, $pollTime, $dbname, $start_date, $end_date;
    global $srcip, $dstip, $srcport, $dstport, $ipv, $protocol;
    global $notdstip, $notsrcip, $notsrcport, $notdstport;
    $out = "";
    $out .= "<div class=titleDisplay><table border=0 width=100% cellpadding=0 cellspacing=0>\n";
    $out .= "<form METHOD=\"GET\" NAME=\"search\" ACTION=\"\">\n";
    $out .= "<tr>";

    $out .= "<td width=250 valign=middle align=center><div style=\"font-size: 10px; color: #DEDEDE\">\n";
    $out .= "SRC <input type=text size=34 maxlength=39 bgcolor=\"#2299bb\" name=\"srcip\" value=\"";
    if ($notsrcip) $out .= "!";
    if (!empty($srcip) && isip4($srcip)) $out .= $srcip;
    $out .= "\">:";
    $out .= "<input type=text size=6 maxlength=5 bgcolor=\"#2299bb\" name=\"srcport\" value=\"";
    if ($notsrcport) $out .= "!";
    if (!empty($srcport) && isport($srcport)) $out .= $srcport;
    $out .= "\">";
    $out .= "</div>\n";
    $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">";
    $out .= "DST <input type=text size=34 maxlength=39 bgcolor=\"#2299bb\" name=\"dstip\" value=\"";
    if ($notdstip) $out .= "!";
    if (!empty($dstip) && isip4($dstip)) $out .= $dstip;
    $out .= "\">:";
    $out .= "<input type=text size=6 maxlength=5 bgcolor=\"#2299bb\" name=\"dstport\" value=\"";
    if ($notdstport) $out .= "!";
    if (!empty($dstport) && isport($dstport)) $out .= $dstport;
    $out .= "\">";
    $out .= "</div></td>";

    $out .= "<td width=60 valign=middle align=center><div style=\"font-size: 10px; color: #DEDEDE\">\n";
    $out .= "<SELECT NAME=\"ipv\"> <OPTION VALUE=\"2\" ";
    if ($ipv == 2) $out .= "SELECTED";
    $out .= ">IPv4</OPTION><OPTION VALUE=\"10\" ";
    if ($ipv == 10) $out .= "SELECTED";
    $out .= ">IPv6</OPTION>";
    $out .= "<OPTION VALUE=\"12\" "; 
    if ($ipv == 12) $out .= "SELECTED";
    $out .= ">IPv4/6</OPTION></SELECT>";
    $out .= "</div>\n";
    $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">\n";
    $out .= "<SELECT NAME=\"protocol\"><OPTION VALUE=\"any\"";
    if ($protocol == "any") $out .= "SELECTED";
    $out .= ">Any</OPTION><OPTION VALUE=\"6\" ";
    if ($protocol == "6") $out .= "SELECTED";
    $out .= ">TCP</OPTION><OPTION VALUE=\"17\" ";
    if ($protocol == "17") $out .= "SELECTED";
    $out .= ">UDP</OPTION><OPTION VALUE=\"1\" ";
    if ($protocol == "1" || $protocol == "58") $out .= "SELECTED";
    $out .= ">ICMP</OPTION>";
    $out .= "</SELECT>";
    $out .= "</div>\n</td>\n";

    $out .= "<td width=250 valign=middle align=center><div style=\"font-size: 10px; color: #DEDEDE\">\n";
    $out .= "From date<input type=text size=20 maxlength=21 bgcolor=\"#2299bb\" name=\"start_date\" value=";
    $out .= "\"" . $start_date . "\">\n";
    $out .= "</div>\n";
    $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">\n";
    $out .= "To date <input type=text size=20 maxlength=21 bgcolor=\"#2299bb\" name=\"end_date\" value=";
    $out .= "\"" . $end_date . "\">\n";
    $out .= "</div></td>";

    $out .= "<td width=40 valign=middle align=center><div style=\"font-size: 10px; color: #DEDEDE\">";
    if ($config["ENABLE_SESSION"] == 1) { # Only show search button if search is enabled
        $out .= "<input TYPE=\"submit\" NAME=\"op\" VALUE=\"Search connection table\">";
    } 
    $out .= "<input TYPE=\"submit\" NAME=\"op\" VALUE=\"Extract pcap\">";
    $out .= "</div></td>";
    
    $out .= "</font></td></tr></table></form></div>";

    // Extract PCAP from log line
    $out .= "<div class=titleDisplay><table border=0 width=100% cellpadding=0 cellspacing=0>";
    $out .= "<form METHOD=\"GET\" NAME=\"logline\" ACTION=\"\">";
    $out .= "<tr>";
    $out .= "<td width=250 valign=middle align=center><div style=\"font-size: 10px; color: #DEDEDE\">";
    $out .= "Event <input type=text size=100 bgcolor=\"#2299bb\" name=\"logline\">\n";
    $out .= "<input TYPE=\"submit\" NAME=\"op\" VALUE=\"Fetch pcap from event\"><br>\n";
    $out .= "Comment <input type=text size=96 bgcolor=\"#2299bb\" name=\"comment\" value=\"No comment\">\n";
    $out .= "<input TYPE=\"submit\" NAME=\"op\" VALUE=\"Store pcap form event\">\n";
    $out .= "</table><div>\n";
    return $out;
}

function showResults() {
    // Show results    
    $out = "<div class=edwardTest>";
    $out .= "<table border=0 width=100% cellpadding=0 cellspacing=0><tr>";
    $out .= "<td valign=top>";
    $out .= doSearchQuery();
    $out .= "</td>";
    $out .= "</tr></table>";
    $out .= "</div>";

    return $out;
}


function infoBox($infomsg) {
	$out = "<!-- infoBox -->\n";
	$out .= "</p><div class=infoDisplay><table align=center border=1 width=300 cellpadding=0 cellspacing=0>\n";
	#$out .= "</p><div class=infoDisplay><table align=center border=0 width=500 cellpadding=0 cellspacing=0>\n";
	$out .= "<td width=100 valign=middle align=center> <div style=\"font-size: 10px; color: #DEDEDE\">\n";
	$out .= "<center>$infomsg</center>";
	$out .= "</td></table>\n";
	$out .= "<!-- /infoBox -->\n";
	return $out;
}

# Calls ofpc-client.pl to extract the data if the user enters a "log" line.
function extractPcapFromLog($action) {
	global $logline, $ofpcuser, $ofpcpass, $comment, $ofpc_client, $debug;

	$out = "<!-- extractPcapFromLog -->\n";

	# Shell out to ofpc-client here. Note the --gui option.
	$exec = "$ofpc_client ";
	$exec .= "--gui -u $ofpcuser -p $ofpcpass "; 
	$exec .= "-a $action ";
	$exec .= "--logline \"$logline\" ";
	$exec .= "--comment \"$comment\" ";

	# Clean up command before we exec it.
	$e = escapeshellcmd($exec);

	# These are defined in ofpc-client.pl
	if ($debug) { print "Exec is $e<br>"; }
	$cmdresult = shell_exec($e);
	list($result,$action,$filename,$size,$md5,$expected_md5,$position,$message) = explode(",",$cmdresult);

	$pathfile=explode("/",$filename);	# Break path and filename from filename
	$file=array_pop($pathfile);		# Pop last element of path/file array

	if ($result) {
		if ($action == "store" ) {
			$infomsg .= "Extract in queue position $position.<br>\n";
			$infomsg .= "Expected filename: $file.<br>\n";
			$out .= infoBox($infomsg);	
		} elseif ( $action == "fetch") {
			serv_pcap("$filename","$file");
			exit(0);
		}
	} else {
		$infomsg = "Error: $message<br>";
		#$infomsg .= "$e";
		$out .= infoBox($infomsg);
	}
	$out .= "<!-- /extractPcapFromLog -->\n";
	$out .= showResults();
	return $out;
}

# Return unix timestamp including seconds.
function stime2unix($stime){
    if (preg_match("/^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d+):(\d+):(\d+)/",$stime, $array)) {
        return mktime ($array[4], $array[5], $array[6], $array[2], $array[3], $array[1]);
    } else {
	return(0);
    }
}

# Calls ofpc-client.pl to extract the traffic when the user selects a session entry in the table

function extractPcapFromSession() {
    global $ofpcuser, $ofpcpass, $ofpc_client, $debug;
	if ($debug) {
		print "Function: extractPcapFromSession\n";
	}

	$array=doSessionQuery();

	$stime = stime2unix($array["start_time"]);
	$etime = stime2unix($array["end_time"]);

	if ($debug) {
		print "Start time is " . $array["start_time"] . " $stime : End time is " . $array["end_time"] ." $etime<br>" ;
	}

	$exec = "$ofpc_client -u $ofpcuser -p $ofpcpass " . 
		" --gui " .
		" --stime " . $stime .
		" --etime " . $etime .
		" --src-addr "  . $array["src_ip"] .
		" --dst-addr "  . $array["dst_ip"] .
		" --src-port "  . $array["src_port"] .
		" --dst-port "  . $array["dst_port"] .
		" --proto "     . $array["ip_proto"];

        if ($debug) { print "openfpc-client CMD: $exec<br>" ; }

	$e = escapeshellcmd($exec);
	$shellresult = shell_exec($e);

	list($result,$action,$filename,$size,$md5,$expected_md5,$position,$message) = explode(",",$shellresult);
	$pathfile=explode("/",$filename);       # Break path and filename from filename 
	$file=array_pop($pathfile);             # Pop last element of path/file array

	if ($debug) {
		print "Not extracting session: Debug enabled<br>";
	} else {
		if ($result) {
			serv_pcap("$filename","$file");
			exit(0);
		} else {
    		    if ($debug) { print "sessions-extract-error: $message<br>" ; }
			$infobox ="Error: $message <br>";
		}
	}

	$out .= infoBox($infobox);	
	return $out;
}

// The "Extract pcap" button doesn't search the DB for session data, it just extracts as requested.
// Why? Well there are two answers to that. 
// 1) I think there will be times when people don't track connection data (storage, CPU, IO limits)
// 2) On a proxy device, there won't be a central DB to search over. This way a quick extraction can
// take place using the proxy-to-node function.
// -Leon 

function extractPcapFromSearch() {
	global $ofpcuser, $ofpcpass,$ofpc_client, $start_date, $end_date, $srcip, $dstip, $srcport, $dstport, $protocol, $debug;

	if ($debug) {
		print "Function: extractPcapFromSearch<br>";
	}

	$exec = "$ofpc_client -u $ofpcuser -p $ofpcpass --gui ";
	$stime = stime2unix($start_date);
	$etime = stime2unix($end_date);

	if ($debug) {
		print "Start date is " . $start_date . " $stime <br> End time is " . $end_date ." $etime<br>" ;
	}

        if ($start_date) { $exec .= " --stime " . $stime; }
	if ($end_date) { $exec .= " --etime " . $etime; }
	if ($srcip) { $exec .= " --src-addr " . $srcip ; }
	if ($dstip) { $exec .= " --dst-addr " . $dstip ; }
	if ($srcport) { $exec .= " --src-port " . $srcport ; }
	if ($dstport) { $exec .= " --dst-port " . $dstport ; }
	if ($protocol) { $exec .= " --proto " . $protocol ; }

	$e = escapeshellcmd($exec);
	$shellresult = shell_exec($e);

	list($result,$action,$filename,$size,$md5,$expected_md5,$position,$message) = explode(",",$shellresult);
	$pathfile=explode("/",$filename);       # Break path and filename from filename 
	$file=array_pop($pathfile);             # Pop last element of path/file array

	if ($result == 1 ) {
		# Success
		$infobox .= "Success! <br>";
		$infobox .= "Exec: $exec <br>";
		$infobox .= "MD5: $md5 <br>";
		$infobox .= "Size: $size <br>";
	} else {
		# Fail on extract
		$infobox .= "Fail! <br>";
		$infobox .= "Result: $result <br>";
		$infobox .= "Error: $message <br>";
		$infobox .= "Size: $size <br>";
		$infobox .= "Error: $exec <br>";
	}

	if ($debug) {
		$out .= infoBox($infobox);	
	} else {
		serv_pcap("$filename","$file");
		exit(0);
	}

	return $out;
}





function dumpDisplay() {
    global $openfpcdir, $tcpdump, $ipv, $mergecap, $mrgtmpdir;
    $dump = "";
   
    $array = doSessionQuery();
    $sddate = dirdate($array["start_time"]);
    $eddate = dirdate($array["end_time"]);
    $sudate = dd2unix($sddate);
    $eudate = dd2unix($eddate);
    $testdata = ses2epoch($array["start_time"]);


    while ( $sudate <= $eudate ) {
        // Should now find all pcaps in dir!
        $tmpdir = "$openfpcdir/" . date("Y-m-d", $sudate) . "/";
        $pcap = list_pcaps_in_dir("$tmpdir");
        if ($pcap) {
            // make the dir to dump pcap carvings
            $mkdircmd = "sudo mkdir -p $mrgtmpdir/" . $array["sessionid"];
            shell_exec("$mkdircmd &");
            for ($i = 0; $i < count($pcap); $i++) {
                // carve out the session from the pcap files
                $dump = "sudo $tcpdump -r $openfpcdir/" . date("Y-m-d", $sudate) . "/" . $pcap[$i] . " ";
                $dump .= "-w $mrgtmpdir/" . $array["sessionid"] . "/" . $array["sessionid"] . "-$i" . ".pcap ";
                if ($ipv == 2)  $dump .= "ip and ";
                if ($ipv == 10) $dump .= "ip6 and ";
                $dump .= "host " . $array["src_ip"] . " and host " . $array["dst_ip"] . " ";
                if ($array["ip_proto"] == 6 || $array["ip_proto"] == 17) {
                    $dump .= "and port " . $array["src_port"] . " and port " . $array["dst_port"] . " ";
                }
                $dump .= "and proto " . $array["ip_proto"];
                $cmd = escapeshellcmd($dump);
                $r1 = shell_exec("$cmd");
            }
        }
    $sudate += 86400;
    }
    // mergecap -w $outfile file1 file2...
    // for files in merged-pcap do...
    $tmpdir2 = $mrgtmpdir . "/" . $array["sessionid"] . "/";
    $mpcap = list_pcaps_in_dir("$tmpdir2");
    if ($mpcap) {
        $flist = "";
        for ($i = 0; $i < count($mpcap); $i++) {
            $flist .= "$tmpdir2/$mpcap[$i] ";
        }
        $mergedfile = $tmpdir2 . $array["sessionid"] . ".pcap";
        $merge  = "sudo $mergecap -w " . $mergedfile . " ";
        $merge .= "$flist";
        $cmd = escapeshellcmd($merge);
        $r2 = shell_exec("$cmd");
    }

    if ($mergedfile && is_file("$mergedfile")) {
        serv_pcap($mergedfile,$array["sessionid"]);
    }

    unset ($array);
    exit(0);
}

function mainHeading() {
    
    $out = "<html><head><title>OpenFPC - Open Full Packet Capture : WebGUI</title>";
    
    $out .= "
    
        <style type=\"text/css\">
        
        body {
            background-color: #ABABAB;
        }

        a {
            color: #000000;
        }

        .titleDisplay table {
            background: #fff url(./bluegrade.png) repeat-x;
            border: 1px solid #454545;
            padding: 2px; 
            margin: 3px;
            height: 15px;
            font-size: 12px;
        }

	.infoDisplay table {
            background: #fff url(./bluegrade.png) repeat-x;
            border: 1px solid #454545;
            padding: 2px;
	    margin-left: auto;
	    margin-right: auto;
            margin: 3px;
            height: 15px;
            font-size: 12px;
	    align: center;
	}

        .edwardTest table {
            padding: 1px;
            margin: 1px;
        }

        .eventBox {
            background: #fff url(./bluegrade.png) repeat-x;
            border: 1px solid #454545;
            padding: 2px; 
            margin: 3px;
            height: 32px;
        } 
        
        .eventBox table {
            font-size: 12px;
        }

        .eventDisplay {
            background: #CDCDCD;
            border: 1px solid #454545;
            padding: 2px; 
            margin: 3px;
            font-size: 12px;
        }

        .eventDisplay table {
            font-size: 10px;
        }

        </style>
    ";
    
    //$out .= "<script LANGUAGE=\"JavaScript\">";
    $out .= "<script type=\"text/javascript\">";
    
    $out .= "
        function SessionWindow(cid,p) {
            window.open( '?op=dump&cxtid='+cid+'&sessp='+p+'&' );
        } 
            ";
    
    $out .= "</script>";
    
    $out .= "</head><body>";
    
    return $out;
}

function mainFooting() {

    $out = "</body></html>";
    
    return $out;
}

// Functions

function doSessionQuery() {
    global $cxtid, $ipv, $sessp, $debug;
    if ($debug) {print "doSessionQuery got: $cxtid, $ipv, $sessp <br>" ; };
    $siteDB = new siteDB();
    //$ipv=$sessp;
    
    if ( $sessp == 2 ) {
        $query = "SELECT sessionid, start_time,end_time,
                 inet_ntoa(src_ip) as src_ip,src_port,
                     inet_ntoa(dst_ip) as dst_ip,dst_port,
                 ip_proto
              FROM session
              WHERE sessionid = '$cxtid' limit 1;";
    }
    else if ( $sessp == 10 ) {
        $query = "SELECT sessionid, start_time,end_time,
                                 inet_ntoa6(src_ip) as src_ip,src_port,
                                 inet_ntoa6(dst_ip) as dst_ip,dst_port,
                                 ip_proto
                          FROM session
                          WHERE sessionid = '$cxtid' limit 1;";
    }
        $siteQ = $siteDB->query($query);
        for ($i = 0; $row = mysql_fetch_row($siteQ); $i++) {

                for ($p = 0; $p < count($row); $p++) {
                        $array[mysql_field_name($siteQ, $p)] = $row[$p];
                }
                //$out .= "<div class=eventBox \">" . eventRowFormat($array) . "</div>";
                //unset($array);
        }
        $siteDB->close();

        return $array;
}

function doSearchQuery() {
    global $maxRows, $srcip, $dstip, $srcport, $dstport, $start_date, $end_date, $debug;
    global $protocol, $ipv, $notsrcip, $notdstip, $notsrcport, $notdstport;
    $out="";
    $siteDB = new siteDB();
    $orderBy = "start_time";

    //if ( preg_match("/^(\d){1,2}$/",$ipv) ) {
    //  if ( $ipv != 2 || $ipv != 10 || $ipv !=12 ) $ipv = 12; 
    //}
    if ($protocol == "any") $protocol = "";

    if ($debug) { print "SRC_IP is $srcip<br>" ; }
    if ($debug) { print "DST_IP is $dstip<br>" ; }

    $query = "";
    if ( $ipv == 2 || $ipv == 12 ) {
            $query = "select sid,sessionid,start_time,end_time,inet_ntoa(src_ip) as src_ip,
              src_port,inet_ntoa(dst_ip) as dst_ip,dst_port,ip_proto,ip_version,
              src_pkts,src_bytes,dst_pkts,dst_bytes,src_flags,dst_flags,duration
                          from session where 
                      start_time > '$start_date' and end_time < '$end_date' and ip_version='2' ";
        if ($ipv == 12) $srcip = $dstip = "";
        if (!empty($srcip) && isip4($srcip)) {
            $query .= "and src_ip ";
            if ($notsrcip) $query .= "!";
            $query .= "= inet_aton('$srcip') ";
        }
        if (!empty($dstip) && isip4($dstip)) {
            $query .= "and dst_ip ";
            if ($notdstip) $query .= "!";
            $query .= "= inet_aton('$dstip') ";
        }
        if (!empty($srcport) && isport($srcport)) {
            $query .= "and src_port ";
            if ($notsrcport) $query .= "!";
            $query .= "= '$srcport' ";
        }
        if (!empty($dstport) && isport($dstport)) {
            $query .= "and dst_port ";
            if ($notdstport) $query .= "!";
            $query .= "= '$dstport' ";
        }
        if (!empty($protocol) && isprotocol($protocol)) $query .= "and ip_proto = '$protocol' ";

        if ( $ipv != 12 ) $query .= "ORDER BY $orderBy DESC limit $maxRows;";
    }

    if ( $ipv == 12 ) $query .= " union ";

    if ( $ipv == 10 || $ipv == 12 ) {
        if ($protocol == 1) $protocol = 58;
        $query .= "select sid,sessionid,start_time,end_time,inet_ntoa6(src_ip) as src_ip,
               src_port,inet_ntoa6(dst_ip) as dst_ip,dst_port,ip_proto,ip_version,
               src_pkts,src_bytes,dst_pkts,dst_bytes,src_flags,dst_flags,duration
                       from session where
                       start_time > '$start_date' and ip_version='10' ";
        if ($ipv == 12) $srcip = $dstip = "";
        if (!empty($srcip) && isip6($srcip)) { 
            $query .= "and src_ip ";
            if ($notsrcip) $query .= "!";
            $query .= "= inet_aton6('$srcip') ";
        }
        if (!empty($dstip) && isip6($dstip)) {
            $query .= "and dst_ip ";
            if ($notdstip) $query .= "!";
            $query .= "= inet_aton6('$dstip') ";
        }
        if (!empty($srcport)) {
            $query .= "and src_port ";
            if ($notsrcport) $query .= "!";
            $query .= "= '$srcport' ";
        }
        if (!empty($dstport)) {
            $query .= "and dst_port ";
            if ($notdstport) $query .= "!";
            $query .= "= '$dstport' ";
        }
        if (!empty($protocol)) $query .= "and ip_proto = '$protocol' ";

        $query .= "ORDER BY $orderBy DESC limit $maxRows;";
    }

	if ($debug) { print "Query is $query<br>" ; }
        $siteQ = $siteDB->query($query);
	
        for ($i = 0; $row = mysql_fetch_row($siteQ); $i++) {
            for ($p = 0; $p < count($row); $p++) {
                $array[mysql_field_name($siteQ, $p)] = $row[$p];
            }

            $out .= "<div class=eventBox \">" . eventRowFormat($array) . "</div>\n";

            unset($array);
        }

        $siteDB->close();

        return $out;
}

function eventRowFormat($data) {

    //$out .= "<div>";
    $out = "<table border=0 width=100% cellpadding=0 cellspacing=0>";
    $out .= "<tr onmouseover=\"this.style.cursor=&#39;hand&#39;\" ";
    //$out .= "onmouseup=\"javascript:opacity(&#39;object1&#39;, 0, 100, 1000);\" ";
    $out .= "onclick=\"SessionWindow('" . $data["sessionid"] . "','" . $data["ip_version"] .  "');\"";
    //$out .= "(&#39;?op=SessionQuery&obj=object1&id=" . $data["sessionid"] . "&s=" . $data["ip_version"] . "&#39;)";
    $out .= ">";
    
    // Sensor
    $out .= "</td><td width=30 valign=middle align=center>";

    //$out .= "<div style=\"font-size: 10px;\">" . $data["cnt"] . "</div>";
    $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . $data["sessionid"] . "</div>";
    $out .= "<div style=\"font-size: 10px; text-align: center;\">cxtid</div>";

    $out .= "</td><td width=12 valign=top>";
    $out .= "&nbsp;";

    // Source IP
    $out .= "</td><td width=80 valign=middle align=center>";

    $out .= "<div style=\"font-size: 10px; text-align: center; color: #DEDEDE\">" . $data["src_ip"] . "</div>";

    $out .= "<div style=\"font-size: 10px; text-align: center;\">Source IP</div>";

    $out .= "</td><td width=1 valign=top>";

    $out .= "&nbsp;";

    // Source PORT
    $out .= "</td><td width=30 valign=middle align=center>";

    $out .= "<div style=\"font-size: 10px; text-align: center; color: #DEDEDE\">";

    if ($data["src_port"]) {
        $out .= $data["src_port"];
    } else {
        $out .= "0";
    }
        
    $out .= "</div>";

    $out .= "<div style=\"font-size: 10px; text-align: center;\">SrcPort</div>";

    $out .= "</td><td width=12 valign=top>";

    $out .= "&nbsp;";

    // Destination IP
    $out .= "</td><td width=80 valign=middle align=center>";

    $out .= "<div style=\"font-size: 10px; text-align: center; color: #DEDEDE\">" . $data["dst_ip"] . "</div>";

    $out .= "<div style=\"font-size: 10px; text-align: center;\">Destination IP</div>";

    $out .= "</td><td width=1 valign=top>";

    $out .= "&nbsp;";

    // Destination PORT
    $out .= "</td><td width=30 valign=middle align=center>";

    $out .= "<div style=\"font-size: 10px; text-align: center; color: #DEDEDE\">";
    
    if ($data["dst_port"]) {
        $out .= $data["dst_port"];
    } else {
        $out .= "0";
    }
    
    $out .= "</div>";
    
    $out .= "<div style=\"font-size: 10px; text-align: center;\">DstPort</div>";
    
    $out .= "</td><td width=15 valign=top>";

    $out .= "&nbsp;";
    
        // Protocol
        $out .= "</td><td width=20 valign=middle align=center>";
                $out .= "<div style=\"font-size: 10px; text-align: center; color: #DEDEDE\">" . $data["ip_proto"] . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">" . "Protocol" . "</div>";

        $out .= "</td><td width=12 valign=top>";

                $out .= "&nbsp;";

        // Duration
        $out .= "</td><td width=20 valign=middle align=center>";
                $out .= "<div style=\"font-size: 10px; text-align: center; color: #DEDEDE\">";
        if ($data["duration"]) {
                        $out .= $data["duration"];
                } else {
                        $out .= "0";
                }
        $out .= "</div>";

                $out .= "<div style=\"font-size: 10px; text-align: center;\">" . "Duration" . "</div>";

        $out .= "</td><td width=12 valign=top>";

                $out .= "&nbsp;";


        // Src_pkts
        $out .= "</td><td width=30 valign=middle align=center>";

                $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . $data["src_pkts"] . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">src_pkts</div>";

        $out .= "</td><td width=2 valign=top>";

                $out .= "&nbsp;";

        // Dst_pkts
        $out .= "</td><td width=30 valign=middle align=center>";

                $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . $data["dst_pkts"] . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">dst_pkts</div>";

        $out .= "</td><td width=12 valign=top>";

                $out .= "&nbsp;";

        // Src_bytes
        $out .= "</td><td width=30 valign=middle align=center>";

                $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . $data["src_bytes"] . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">src_bytes</div>";

        $out .= "</td><td width=2 valign=top>";

                $out .= "&nbsp;";

        // Dst_bytes
        $out .= "</td><td width=30 valign=middle align=center>";

                $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . $data["dst_bytes"] . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">dst_bytes</div>";

        $out .= "</td><td width=12 valign=top>";

                $out .= "&nbsp;";

        // Src_flags
        $out .= "</td><td width=30 valign=middle align=center>";

                $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . tftoa($data["src_flags"]) . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">src_flags</div>";

        $out .= "</td><td width=2 valign=top>";

                $out .= "&nbsp;";

        // Dst_flags
        $out .= "</td><td width=30 valign=middle align=center>";

                $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">" . tftoa($data["dst_flags"]) . "</div>";
                $out .= "<div style=\"font-size: 10px; text-align: center;\">dst_flags</div>";

        $out .= "</td><td width=2 valign=top>";

                $out .= "&nbsp;";

    // Time info col
    $out .= "</td><td valign=top align=right>";

        $out .= "<div style=\"font-size: 10px; color: #DEDEDE\">Start " . $data["start_time"] . "</div>";
        $out .= "<div style=\"font-size: 10px; color: #DEDEDE\"> End  " . $data["end_time"] . "</div>";

    $out .= "</td>";
    $out .= "</tr></table>";
    //$out .= "</div>";

    return $out;
    
}

// Support Functions

function pollParse($data) {

    $obj = getVar("obj");
    if (empty($obj)) $obj = "object1";

    header ("Content-type: text/javascript");

    echo "document.getElementById('$obj').innerHTML='$data';";

    unset($data, $obj);
}

// tcp Flags to ascii
function tftoa($flags) {
    $out = "";
    
    if ( $flags & 0x01 ) $out .= "F";
    if ( $flags & 0x02 ) $out .= "S";
    if ( $flags & 0x04 ) $out .= "R";
    if ( $flags & 0x08 ) $out .= "P";
    if ( $flags & 0x10 ) $out .= "A";
    if ( $flags & 0x20 ) $out .= "U";
    if ( $flags & 0x40 ) $out .= "E";
    if ( $flags & 0x80 ) $out .= "C";

    if ( $out == "" ) $out .= "-";
    return $out;
}

// ascii to tcp Flags
function atotf($in) {
        $flags = 0x00;

    if (preg_match("/F/",$in)) $flags = $flags | 0x01;
    if (preg_match("/S/",$in)) $flags = $flags | 0x02;
    if (preg_match("/R/",$in)) $flags = $flags | 0x04;
    if (preg_match("/P/",$in)) $flags = $flags | 0x08;
    if (preg_match("/A/",$in)) $flags = $flags | 0x10;
    if (preg_match("/U/",$in)) $flags = $flags | 0x20;
    if (preg_match("/E/",$in)) $flags = $flags | 0x40;
    if (preg_match("/C/",$in)) $flags = $flags | 0x80;

        return $flags;
}

function backdate($days) {
        $backdate = mktime(0, 0, 0, date("m"), date("d")-$days, date("y"));
        return date("Y-m-d", $backdate);
}

function forwarddate($days) {
        $backdate = mktime(0, 0, 0, date("m"), date("d")+$days, date("y"));
        return date("Y-m-d", $backdate);
}

function sanitize($in) {
    return strip_tags(addslashes(getVar($in)));
}

function valdate($sd) {
    // 2009-12-22 18:44:35
    if (preg_match("/^(\d\d\d\d)-(\d\d)-(\d\d)( \d\d:\d\d:\d\d)?$/",$sd,$array)) {
        if(checkdate($array[2],$array[3],$array[1])) {
            return true;
        } else {
            return false;
        }
    } else {
        return false;
    }
}

function is_not_set($string) {
    // !192.168.0.1 or !443
    if (preg_match("/^!/",$string)) {
        return true;
    } else {
        return false;
    }
}

function strip_not($string) {
    // !192.168.0.1 or !443
    if (preg_match("/^(!)(.*)/",$string,$array)) {
                return $array[2];
        } else {
                return $string;
        }
}

function dirdate($dd) {
    // 2009-12-22
    if (preg_match("/^(\d\d\d\d)-(\d\d)-(\d\d)/",$dd,$array)) {
        $out = $array[1] . "-" . $array[2] . "-" . $array[3];
        return $out;
    } else {
        return false;
    }
}

function dd2unix($dd){
    if (preg_match("/^(\d\d\d\d)-(\d\d)-(\d\d)/",$dd,$array)) {
        return mktime (0, 0, 0, $array[2], $array[3], $array[1]);
    }
}

function isport($port) {
    // 0 - 65535
    if (preg_match("/^([\d]){1,5}$/",$port) && $port >= 0 && $port <= 65535) {
        return true;
    } else {
        return false;
    }
}

function isprotocol($protocol) {
    // 0 - 255
    if (preg_match("/^([\d]){1,3}$/",$protocol) && $protocol >= 0 && $protocol <= 255) {
                return true;
        } else {
                return false;
        }
}

function isip4($ip) {
        // ddd.ddd.ddd.ddd
        if (substr_count($ip,".") == 3) {
                if (preg_match("/^([\d]{1,3}\.){3}[\d]{1,3}$/",$ip)) {
                     return true;
                }
        } else {
                return false;
        }
}

function isip6($ip) {
        // hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh
        if (substr_count($ip,":") > 1 && substr_count($ip,":") < 8 && substr_count($ip,".") == 0){
                $uip = uncompress_ipv6($ip);
                if (!ereg('^:',$uip) && !ereg(':$',$uip) && !ereg('::',$uip) ) {
                        if ( preg_match("/^([a-f\d]{4}:){7}[a-f\d]{4}$/",$uip) ) {
                                return true;
                        }
                }
        } else {
                return false;
        } 
}

function uncompress_ipv6($ip ="") {
    if(strstr($ip,"::" )) {
        $e = explode(":", $ip);
        $s = 8-sizeof($e);
        foreach ($e as $key=>$val) {
                if ($val == "") {
                    for($i==0;$i<=$s;$i++) {
                        $newip[] = "0000";
                }
                } else {
                    $newip[] = $val;
                }
        }
        $ip = implode(":", $newip);
    }
    return $ip;
} 

function getVar($in) {

    if (isset($_POST[$in])) {
        $out = $_POST[$in];
    } else {
        $out = $_GET[$in];
    }
    
    if (get_magic_quotes_gpc()) {
        if (is_array($out)) {
            foreach ($out as $el) {
                $array[] = stripslashes($el);
            }
            $out = $array;
        } else {
            $out = stripslashes($out);
        }    
    }
        
    return $out;
}

function list_pcaps_in_dir($_dir) {
    if (is_dir($_dir)) {
        $files = scandir($_dir);
        $i = 0;
        $array[$i] = "";
        foreach($files as $key => $file){
            $dirfile =  "$_dir" . "$file";
            if (is_file("$dirfile")) {
                $cmd = escapeshellcmd($dirfile);
                $output = shell_exec("file \"$cmd\"");
                if (is_file_pcap("$output")) {
                    $array[$i] = $file;
                    $i++;
                }
            }
        }
        return $array[$i];
    } else {
        return false;
    }
}

function is_file_pcap($_file) {
    // " tcpdump capture file "
    if (preg_match("/ tcpdump capture file /",$_file)) {
        return true;
    } else {
        return false;
    }
}

function serv_pcap($filepath,$cxid) {
    header('Content-Type: application/pcap-capture');
    header("Content-Disposition: attachment; filename=\"$cxid\"");
    readfile("$filepath");
    #exit(0);
}

class siteDB {
    function siteDB() {
        global $dbhost, $dbuser, $dbpass, $dbname, $debug;

        $this->host = chop($dbhost);
        $this->db   = chop($dbname);
        $this->user = chop($dbuser);
        $this->pass = chop($dbpass);
        $this->link = mysql_connect($this->host, $this->user, $this->pass, 1);

        $connected = mysql_select_db($this->db);
        if (!$connected) {
		if ($debug) print "Error unable to connect to Database!";
	}

    }

    function query($query) {
        
        if ($result = @mysql_query($query, $this->link)) {
            return $result;
        }
    }

    function close() {
        
        @mysql_close($this->link);
    }
}

?>
