/* Terraria LXC — panel de control. Sin dependencias. */
'use strict';

const $ = (sel, root = document) => root.querySelector(sel);

const SIZES = { 1: 'Pequeño', 2: 'Mediano', 3: 'Grande' };
const DIFFICULTIES = { 0: 'Clásico', 1: 'Experto', 2: 'Maestro', 3: 'Viaje' };
const STATES = {
    creating: 'Creando…',
    starting: 'Generando mundo…',
    online:   'En línea',
    offline:  'Apagado',
    busy:     'Ocupado…',
    error:    'Error',
    missing:  'Sin contenedor',
};
const POLL_MS = 4000;

let host = '';
let servers = [];
let pending = new Set();      // servidores con una acción en curso
let pollTimer = null;

/* --- API ------------------------------------------------------------------ */

async function api(action, { body, params } = {}) {
    const url = new URL('api.php', location.href);
    url.searchParams.set('action', action);
    for (const [k, v] of Object.entries(params || {})) url.searchParams.set(k, v);

    const opts = body === undefined ? {} : {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Panel': '1' },
        body: JSON.stringify(body),
    };
    let res, data;
    try {
        res = await fetch(url, opts);
        data = await res.json();
    } catch {
        throw new Error('No hay respuesta del servidor. ¿Está Apache encendido?');
    }
    if (!res.ok || data.ok === false) throw new Error(data.error || `Error ${res.status}`);
    return data;
}

/* --- Avisos --------------------------------------------------------------- */

function toast(message, type = 'ok') {
    const el = document.createElement('div');
    el.className = `toast${type === 'error' ? ' toast--error' : ''}`;
    el.textContent = message;
    $('#toasts').append(el);
    setTimeout(() => el.remove(), type === 'error' ? 8000 : 4000);
}

/* --- Lista de mundos ------------------------------------------------------ */

function formatMemory(bytes) {
    if (!bytes) return null;
    const mib = bytes / 1048576;
    return mib >= 1024 ? `${(mib / 1024).toFixed(1)} GB de RAM` : `${Math.round(mib)} MB de RAM`;
}

function noteFor(s) {
    switch (s.state) {
        case 'creating': return 'Preparando el contenedor y copiando el servidor. Tarda uno o dos minutos.';
        case 'starting': return 'El servidor está generando o cargando el mundo. Aparecerá en línea en cuanto acepte jugadores.';
        case 'error':    return s.error || 'La creación falló. Abre la consola para ver el motivo.';
        case 'missing':  return 'El contenedor ya no existe en LXD. Borra este mundo para liberar el puerto.';
        default:         return '';
    }
}

function renderWorld(s) {
    const node = $('#world-template').content.firstElementChild.cloneNode(true);
    node.dataset.name = s.name;
    node.dataset.state = s.state;

    const f = (key) => node.querySelector(`[data-f="${key}"]`);
    f('world').textContent = s.world;
    f('name').textContent = `Contenedor tlxc-${s.name}`;
    f('state').textContent = STATES[s.state] || s.state;
    f('address').textContent = `${host}:${s.port}`;

    const detail = [
        SIZES[s.size],
        DIFFICULTIES[s.difficulty],
        `${s.players} jugadores`,
        s.has_password ? 'con contraseña' : 'sin contraseña',
        s.seed ? `semilla «${s.seed}»` : null,
        `Terraria ${s.version}`,
        formatMemory(s.memory),
    ].filter(Boolean);
    f('detail').textContent = detail.join(', ');

    const note = noteFor(s);
    f('note').hidden = !note;
    f('note').textContent = note;

    const busy = pending.has(s.name);
    const running = s.state === 'online' || s.state === 'starting';
    const ready = !['creating', 'error', 'missing'].includes(s.state);
    const btn = (act) => node.querySelector(`[data-act="${act}"]`);
    btn('start').hidden = running || !ready;
    btn('stop').hidden = !running;
    btn('restart').hidden = !running;
    btn('copy').disabled = !ready;
    for (const act of ['start', 'stop', 'restart', 'delete']) btn(act).disabled = busy;
    btn('delete').disabled = busy || s.state === 'creating';
    return node;
}

function render() {
    const list = $('#world-list');
    const online = servers.filter((s) => s.state === 'online').length;
    $('#sum-online').textContent = online;
    $('#sum-total').textContent = servers.length;
    $('#sum-host').textContent = host || '–';

    if (!servers.length) {
        list.innerHTML = '';
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.innerHTML = '<strong>Aún no hay mundos</strong>Crea el primero con el formulario. Cada mundo va en su propio contenedor.';
        list.append(empty);
        return;
    }

    // Conservar el foco del teclado entre repintados
    const active = document.activeElement;
    const focusKey = active?.closest?.('.world') &&
        [active.closest('.world').dataset.name, active.dataset.act];

    list.replaceChildren(...servers.map(renderWorld));

    if (focusKey) {
        $(`.world[data-name="${focusKey[0]}"] [data-act="${focusKey[1]}"]`, list)?.focus();
    }
}

async function refresh() {
    try {
        const data = await api('list');
        host = data.host;
        servers = data.servers;
        render();
    } catch (err) {
        $('#world-list').innerHTML = '';
        const p = document.createElement('p');
        p.className = 'empty';
        p.textContent = err.message;
        $('#world-list').append(p);
    }
}

function startPolling() {
    clearInterval(pollTimer);
    pollTimer = setInterval(() => { if (!document.hidden) refresh(); }, POLL_MS);
}

/* --- Acciones de cada mundo ---------------------------------------------- */

const DONE = {
    start:   (w) => `${w} encendido. El mundo tardará unos segundos en cargar.`,
    stop:    (w) => `${w} apagado. El mundo se ha guardado.`,
    restart: (w) => `${w} reiniciado.`,
    delete:  (w) => `${w} borrado.`,
};

async function runAction(action, server) {
    pending.add(server.name);
    render();
    try {
        await api(action, { body: { name: server.name } });
        toast(DONE[action](server.world));
    } catch (err) {
        toast(err.message, 'error');
    } finally {
        pending.delete(server.name);
        await refresh();
    }
}

$('#world-list').addEventListener('click', async (ev) => {
    const button = ev.target.closest('[data-act]');
    if (!button) return;
    const server = servers.find((s) => s.name === button.closest('.world').dataset.name);
    if (!server) return;

    switch (button.dataset.act) {
        case 'copy':
            try {
                await navigator.clipboard.writeText(`${host}:${server.port}`);
                toast('Dirección copiada. Pégala en «Unirse por IP».');
            } catch {
                toast(`Dirección: ${host}:${server.port}`);
            }
            break;
        case 'console':
            openConsole(server);
            break;
        case 'delete':
            askDelete(server);
            break;
        default:
            runAction(button.dataset.act, server);
    }
});

/* --- Borrar --------------------------------------------------------------- */

const deleteDialog = $('#delete-dialog');
let toDelete = null;

function askDelete(server) {
    toDelete = server;
    $('#delete-title').textContent = `¿Borrar «${server.world}»?`;
    deleteDialog.showModal();
    deleteDialog.querySelector('[data-close]').focus();
}

$('#delete-confirm').addEventListener('click', () => {
    deleteDialog.close();
    if (toDelete) runAction('delete', toDelete);
    toDelete = null;
});

/* --- Consola -------------------------------------------------------------- */

const consoleDialog = $('#console-dialog');
const consoleOut = $('#console-output');
let consoleServer = null;
let consoleTimer = null;

async function loadConsole() {
    if (!consoleServer) return;
    try {
        const data = await api('console', { params: { name: consoleServer.name } });
        const atBottom = consoleOut.scrollHeight - consoleOut.scrollTop - consoleOut.clientHeight < 40;
        consoleOut.textContent = data.text.replace(/\s+$/, '') || '(vacío)';
        if (atBottom) consoleOut.scrollTop = consoleOut.scrollHeight;
    } catch (err) {
        consoleOut.textContent = err.message;
    }
}

function openConsole(server) {
    consoleServer = server;
    $('#console-title').textContent = `Consola de ${server.world}`;
    consoleOut.textContent = 'Cargando…';
    const canSend = server.state === 'online' || server.state === 'starting';
    for (const el of consoleDialog.querySelectorAll('[data-cmd], #console-form input, #console-form button')) {
        el.disabled = !canSend;
    }
    consoleDialog.showModal();
    loadConsole().then(() => { consoleOut.scrollTop = consoleOut.scrollHeight; });
    consoleTimer = setInterval(loadConsole, 2000);
    if (canSend) $('#console-form input').focus();
}

consoleDialog.addEventListener('close', () => {
    clearInterval(consoleTimer);
    consoleServer = null;
});

async function sendCommand(command) {
    if (!consoleServer || !command) return;
    try {
        await api('send', { body: { name: consoleServer.name, command } });
        setTimeout(loadConsole, 400);
    } catch (err) {
        toast(err.message, 'error');
    }
}

$('#console-form').addEventListener('submit', (ev) => {
    ev.preventDefault();
    const input = ev.target.command;
    sendCommand(input.value.trim());
    input.value = '';
});

consoleDialog.addEventListener('click', (ev) => {
    const cmd = ev.target.closest('[data-cmd]');
    if (cmd) sendCommand(cmd.dataset.cmd);
});

for (const btn of document.querySelectorAll('[data-close]')) {
    btn.addEventListener('click', () => btn.closest('dialog').close());
}

/* --- Crear mundo ---------------------------------------------------------- */

const form = $('#create-form');
const els = form.elements;  // els.name sería el atributo name del <form>, no el campo
const formError = $('#form-error');
let nameEdited = false;

function slugify(text) {
    return text.normalize('NFD').replace(/[̀-ͯ]/g, '')
        .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^[^a-z]+/, '')
        .slice(0, 24).replace(/-+$/, '');
}

els.world.addEventListener('input', () => {
    if (!nameEdited) els.name.value = slugify(els.world.value);
});
els.name.addEventListener('input', () => {
    nameEdited = els.name.value !== '';
    els.name.value = els.name.value.toLowerCase().replace(/[^a-z0-9-]/g, '');
});

function validate() {
    const problems = [];
    const mark = (input, bad) => input.setAttribute('aria-invalid', bad ? 'true' : 'false');

    const world = els.world.value.trim();
    const badWorld = !/^[\p{L}\p{N} _.\-]{1,32}$/u.test(world);
    mark(els.world, badWorld);
    if (badWorld) problems.push('El nombre del mundo admite letras, números, espacios, guiones y puntos (máximo 32).');

    const badName = !/^[a-z][a-z0-9-]{1,22}[a-z0-9]$/.test(els.name.value);
    mark(els.name, badName);
    if (badName) problems.push('El identificador debe tener de 3 a 24 caracteres, empezar por letra y no acabar en guion.');
    else if (servers.some((s) => s.name === els.name.value)) {
        mark(els.name, true);
        problems.push('Ya tienes un mundo con ese identificador.');
    }

    const players = Number(els.players.value);
    const badPlayers = !Number.isInteger(players) || players < 1 || players > 32;
    mark(els.players, badPlayers);
    if (badPlayers) problems.push('El número de jugadores va de 1 a 32.');

    const badSeed = !/^[\p{L}\p{N} _.\-]{0,40}$/u.test(els.seed.value.trim());
    mark(els.seed, badSeed);
    if (badSeed) problems.push('La semilla admite letras, números, espacios, guiones y puntos.');

    formError.hidden = !problems.length;
    formError.textContent = problems[0] || '';
    return !problems.length;
}

form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    if (!validate()) {
        form.querySelector('[aria-invalid="true"]')?.focus();
        return;
    }
    const submit = form.querySelector('[type="submit"]');
    submit.disabled = true;
    submit.textContent = 'Creando…';
    try {
        await api('create', {
            body: {
                name: els.name.value,
                world: els.world.value.trim(),
                size: Number(els.size.value),
                difficulty: Number(els.difficulty.value),
                players: Number(els.players.value),
                seed: els.seed.value.trim(),
                password: els.password.value,
            },
        });
        toast(`Creando «${els.world.value.trim()}». Aparecerá en línea en un par de minutos.`);
        form.reset();
        nameEdited = false;
        await refresh();
    } catch (err) {
        formError.hidden = false;
        formError.textContent = err.message;
    } finally {
        submit.disabled = false;
        submit.textContent = 'Crear mundo';
    }
});

/* --- Terreno pixelado de la cabecera ------------------------------------- */

function drawTerrain() {
    const B = 8;                     // tamaño de bloque en px
    const cols = 160;                // ancho del mosaico: 1280 px, se repite sin cortes
    const rows = 6;
    let seed = 7;
    const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

    // Alturas que suben y bajan de bloque en bloque y cierran igual que empiezan
    const heights = [];
    let h = 3;
    for (let x = 0; x < cols; x++) {
        const r = rand();
        if (r < 0.18 && h < rows - 1) h++;
        else if (r > 0.82 && h > 1) h--;
        if (x > cols - 6) h += Math.sign(3 - h);
        heights.push(h);
    }

    let rects = '';
    for (let x = 0; x < cols; x++) {
        const top = rows - heights[x];
        for (let y = top; y < rows; y++) {
            let fill = '#7a5236';
            if (y === top) fill = rand() < 0.3 ? '#86cf55' : '#5fae3b';
            else if (y === top + 1 && rand() < 0.5) fill = '#4f8f31';
            else if (rand() < 0.12) fill = '#5c3c27';
            else if (rand() < 0.04) fill = '#6f6a86';
            rects += `<rect x="${x * B}" y="${y * B}" width="${B}" height="${B}" fill="${fill}"/>`;
        }
        // Algún tallo de hierba suelto
        if (rand() < 0.08) rects += `<rect x="${x * B + 2}" y="${(top - 1) * B + 3}" width="3" height="5" fill="#5fae3b"/>`;
    }
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${cols * B}" height="${rows * B}" shape-rendering="crispEdges">${rects}</svg>`;
    $('.terrain').style.backgroundImage = `url("data:image/svg+xml,${encodeURIComponent(svg)}")`;
}

/* --- Inicio --------------------------------------------------------------- */

drawTerrain();
refresh();
startPolling();
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
