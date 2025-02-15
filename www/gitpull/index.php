<?php /* error_reporting(E_ALL); ini_set('display_errors',1);*/ $path = "/home/bitrix/git/"; $result = ""; $output = array(); $response = [ "error" => "no auth data",
    "success" => 0
];
$token = "<your-webhook-token>"; // enter this token when setup gitlab webhook
$headers = apache_request_headers();
if (!empty($headers) && isset($headers['X-Gitlab-Token']) && $headers['X-Gitlab-Token'] == $token) {
    $response = [
        "error" => "",
        "success" => 1
    ];
}

ob_end_clean();
ignore_user_abort();
ob_start();
header("Connection: close");
header('Content-type:application/json;charset=utf-8');
echo json_encode($response);
header("Content-Length: " . ob_get_length());
ob_end_flush();
flush();

if (!empty($headers) && isset($headers['X-Gitlab-Token']) && $headers['X-Gitlab-Token'] == $token) {
    $result = exec('/bin/sh '.$path.'git.pull.sh '.$_SERVER['SERVER_NAME'].'  2>&1', $output);
    file_put_contents($path.'logs/'.date('d.m.y').'.log', print_r(array(
        "time" => date("d.m.Y H:i:s"),
        "result" => $result,
        "output" => $output
    ), true), FILE_APPEND);
}