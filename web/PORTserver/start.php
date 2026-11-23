<?php
if (isset($_POST['container'])) {
    $container = escapeshellarg($_POST['container']);
    $output = shell_exec("sudo /bin/bash /var/www/html/PORTserver/encender.sh $container 2>&1");
    echo "<pre>$output</pre><a href='../index.html'>Volver</a>";
}
?>
