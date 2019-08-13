<?php

$hostPort = explode(":", $_SERVER['HTTP_HOST']);
$port = $hostPort[1];
	
//if ($_SERVER['REQUEST_METHOD'] === 'POST') {
	$data = file_get_contents("php://input");
	$url = 'http://localhost:8080'.$_SERVER['REQUEST_URI'];
	$ch = curl_init($url);
	
	curl_setopt($ch, CURLOPT_POST, 1);
	curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	
	$response = curl_exec($ch);
	curl_close($ch);
	
	header('Content-Type: application/json');
	echo $response;
//}else{
//	echo "ATS MobileStation started on port ".$port;
//}
// iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAACXBIWXMAAC4jAAAuIwF4pT92AAAAB3RJTUUH4wgNCzQS2tg9zgAAABl0RVh0Q29tbWVudABDcmVhdGVkIHdpdGggR0lNUFeBDhcAAAAMSURBVAjXY2DY/QYAAmYBqC0q4zEAAAAASUVORK5CYII=
?>