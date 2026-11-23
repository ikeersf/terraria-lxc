<?php 
if ($_SERVER["REQUEST_METHOD"] == "POST") { 
    $container_name = escapeshellarg($_POST["container_name"]); 
    $seed = escapeshellarg($_POST["seed"]); 
    $world_name = escapeshellarg($_POST["world_name"]); 
    $players = escapeshellarg($_POST["players"]); 
    $password = escapeshellarg($_POST["password"]); 
    $difficulty = escapeshellarg($_POST["difficulty"]); 

    $command = "sudo /bin/bash /var/www/scripts/crear_contenedor.sh --contenedor=$container_name --semilla=$seed --mundo=$world_name --dificultad=$difficulty --jugadores=$players --contraseña=$password"; 
    $output = shell_exec($command . " 2>&1"); 

    if (strpos($output, "ya existe") !== false) { 
        $status = "Servidor ya existente"; 
    } else if (strpos($output, "Creando el contenedor") !== false) { 
        $status = "Servidor creado correctamente"; 
    } else { 
        $status = "Error al crear el servidor"; 
    } 
} 
?> 
<!DOCTYPE html> 
<html lang="es"> 
<head> 
<meta charset="UTF-8"> 
<meta name="viewport" content="width=device-width, initial-scale=1.0"> 
<title>Estado del Servidor</title> 
<style> 
@import url('https://fonts.googleapis.com/css2?family=Press+Start+2P&display=swap'); 
body { 
background: url('https://i.redd.it/zajy8wh63xl51.gif') no-repeat center center fixed; background-size: cover; 
font-family: 'Press Start 2P', cursive; text-align: center; 
color: #fff; 
}
.container { background: rgba(0, 0, 0, 0.85); padding: 30px; border-radius: 10px; display: inline-block; margin-top: 50px; border: 2px solid #0f5; width: 80%; max-width: 600px; }
.status { font-size: 16px; margin-bottom: 25px; }
.info { text-align: left; margin-left: auto; margin-right: auto; background: #222; padding: 20px; border: 2px solid #0f5; border-radius: 5px; font-size: 12px; line-height: 2; }
button { font-family: 'Press Start 2P', cursive; font-size: 14px; margin-top: 25px; padding: 10px 20px; border: 2px solid #0f5; border-radius: 5px; background: #0a5; color: #fff; cursor: pointer; }
button:hover { background: #0f5; color: #000; }
.error { color: red; }
.success { color: #0f5; }
</style> 
</head> 
<body> 
<div class="container"> 
<h2>Estado del Servidor</h2> 
<p class="status <?php echo ($status == 'Error al crear el servidor') ? 'error' : 'success'; ?>">
<?php echo $status; ?>
</p>
<?php if ($status !== "Error al crear el servidor") { ?>
<div class="info">
<p><b>Nombre:</b> <?php echo $container_name; ?></p>
<p><b>Semilla:</b> <?php echo $seed; ?></p>
<p><b>Mundo:</b> <?php echo $world_name; ?></p>
<p><b>Jugadores:</b> <?php echo $players; ?></p>
<p><b>Dificultad:</b> <?php echo ($difficulty == 1) ? "Normal" : (($difficulty == 2) ? "Experto" : "Maestro"); ?></p>
</div>
<?php } ?>
<br>
<button onclick="window.location.href='index.html'">Volver al Panel</button>
</div>
</body>
</html>
