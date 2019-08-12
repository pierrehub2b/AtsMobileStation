<?php
$fp = fsockopen("localhost", 8080, $errno, $errstr, 30);
if (!$fp) {
	echo "$errstr ($errno)";
} else {
	$out = "POST /info HTTP/1.1\r\n";
	$out .= "Host: com.ats.driver\r\n";
	$out .= "Connection: Close\r\n\r\n";
	fwrite($fp, $out);
	while (!feof($fp)) {
		echo fgets($fp, 128);
	}
	fclose($fp);
}
?>