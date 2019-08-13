<?php

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
	$url = 'http://localhost:8080'.$_SERVER['REQUEST_URI'];
	$ch = curl_init($url);
	
	curl_setopt($ch, CURLOPT_POST, 1);
	curl_setopt($ch, CURLOPT_POSTFIELDS, $HTTP_RAW_POST_DATA);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	
	$response = curl_exec($ch);
	curl_close($ch);
	
	$verif = "";
	foreach($_POST as $value){
    	$verif .= $value;
	}
	echo "{'data':'".$HTTP_RAW_POST_DATA."'}";
}else{
	$hostPort = explode(":", $_SERVER['HTTP_HOST']);
	echo "ATS MobileStation started on port : " + $hostPort[1];
}

?>