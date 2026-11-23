<?php
header('Content-Type: text/plain');
// Obtenemos nombre, estado e IP de LXD (formato CSV)
$output = shell_exec("sudo lxc list --format csv -c n,s,4 2>&1");
echo $output;
?>
