<?php
/**
 * API JSON del panel. Toda la lógica está en /usr/local/sbin/terraria-lxc,
 * que valida las entradas; aquí solo se traducen peticiones HTTP a llamadas.
 *
 *   GET  api.php?action=list
 *   GET  api.php?action=console&name=X
 *   POST api.php?action=create            (cuerpo JSON)
 *   POST api.php?action=start|stop|restart|delete   {"name": "X"}
 *   POST api.php?action=send              {"name": "X", "command": "say hola"}
 */
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

const CLI  = '/usr/local/sbin/terraria-lxc';
const CONF = '/etc/terraria-lxc/terraria-lxc.conf';

function reply(array $data, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function fail(string $message, int $status = 400): never
{
    reply(['ok' => false, 'error' => $message], $status);
}

/** Ejecuta el gestor con sudo y devuelve su salida JSON decodificada. */
function cli(array $args, ?string $stdin = null): array
{
    $cmd = 'sudo -n ' . CLI . ' ' . implode(' ', array_map('escapeshellarg', $args));
    $proc = proc_open($cmd, [['pipe', 'r'], ['pipe', 'w'], ['pipe', 'w']], $pipes);
    if (!is_resource($proc)) {
        fail('No se pudo ejecutar el gestor.', 500);
    }
    fwrite($pipes[0], $stdin ?? '');
    fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]);
    $err = trim((string) stream_get_contents($pipes[2]));
    fclose($pipes[1]);
    fclose($pipes[2]);
    $code = proc_close($proc);

    if ($code !== 0) {
        if (str_contains($err, 'a password is required') || str_contains($err, 'not allowed')) {
            fail('Apache no tiene permiso para usar el gestor. Vuelve a ejecutar install.sh.', 500);
        }
        fail($err !== '' ? $err : 'El gestor terminó con un error inesperado.', 500);
    }
    $data = json_decode((string) $out, true);
    if (!is_array($data)) {
        fail('Respuesta no válida del gestor.', 500);
    }
    return $data;
}

function publicHost(): string
{
    // El archivo tiene formato de shell (comentarios con #), no INI.
    $host = '';
    $conf = @file_get_contents(CONF);
    if ($conf !== false && preg_match('/^PUBLIC_HOST=["\']?([^"\'\s]*)/m', $conf, $m)) {
        $host = $m[1];
    }
    if ($host === '') {
        $host = (string) ($_SERVER['SERVER_ADDR'] ?? $_SERVER['SERVER_NAME'] ?? 'localhost');
    }
    return str_contains($host, ':') ? "[$host]" : $host; // IPv6
}

$action = (string) ($_GET['action'] ?? '');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET') {
    switch ($action) {
        case 'list':
            reply(['ok' => true, 'host' => publicHost(), 'servers' => cli(['list'])]);
        case 'console':
            reply(['ok' => true] + cli(['console', (string) ($_GET['name'] ?? '')]));
    }
    fail('Acción no válida.', 404);
}

if ($method !== 'POST') {
    fail('Método no permitido.', 405);
}

// Protección CSRF: un formulario de otra web no puede añadir esta cabecera.
if (($_SERVER['HTTP_X_PANEL'] ?? '') !== '1') {
    fail('Petición rechazada.', 403);
}

$body = json_decode((string) file_get_contents('php://input'), true);
if (!is_array($body)) {
    fail('El cuerpo de la petición no es JSON válido.');
}
$name = (string) ($body['name'] ?? '');

switch ($action) {
    case 'create':
        $payload = [
            'name'       => $name,
            'world'      => trim((string) ($body['world'] ?? '')),
            'size'       => (int) ($body['size'] ?? 0),
            'difficulty' => (int) ($body['difficulty'] ?? -1),
            'players'    => (int) ($body['players'] ?? 0),
            'seed'       => trim((string) ($body['seed'] ?? '')),
            'password'   => (string) ($body['password'] ?? ''),
        ];
        reply(['ok' => true, 'server' => cli(['create'], json_encode($payload, JSON_UNESCAPED_UNICODE))]);
    case 'start':
    case 'stop':
    case 'restart':
    case 'delete':
        reply(cli([$action, $name]));
    case 'send':
        reply(cli(['send', $name, (string) ($body['command'] ?? '')]));
}
fail('Acción no válida.', 404);
