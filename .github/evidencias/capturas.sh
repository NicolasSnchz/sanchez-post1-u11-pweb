#!/usr/bin/env bash
# Corre dentro de xvfb-run. La aplicacion refactorizada se levanta en una xterm propia (su consola es la
# captura logs-consola.png); el resto son xterm que ejecutan terminal/<nombre>.txt y Chromium para Swagger.
# uso: capturas.sh <carpeta-capturas> <carpeta-temporal> <carpeta-evid>
CAP=$1; TMP=$2; EVID=$3
H=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$H/../.." && pwd)
cd "$REPO"

xterm_de() {  # nombre -> abre la xterm con terminal/<nombre>.txt; devuelve el pid
    xterm -geometry 160x58+0+0 -fa 'DejaVu Sans Mono' -fs 9 -bg '#0d1117' -fg '#c9d1d9' -T "$1" \
        -e bash "$H/mostrar.sh" "$H/terminal/$1.txt" "$TMP/listo-$1" > /dev/null 2>&1 &
    echo $!   # sin la redireccion, $(xterm_de ...) esperaria a que se cierre la xterm
}
foto() {  # nombre -> captura solo esa ventana
    sleep 2
    import -window "$(xwininfo -name "$1" | awk '/Window id:/{print $4}')" "$CAP/$1.png" && echo "captura $1.png"
}
capturar() {  # nombre -> xterm, espera a que termine, captura y cierra
    rm -f "$TMP/listo-$1"
    local pid; pid=$(xterm_de "$1")
    for i in $(seq 1 600); do [ -f "$TMP/listo-$1" ] && break; sleep 1; done
    foto "$1"
    kill "$pid" 2>/dev/null
    sleep 1
}

# Codigo de partida (8081) y compilacion de la version refactorizada
capturar partida-antes
capturar compilacion             # hace clean compile: el jar se empaqueta despues
(cd pedidos && ./mvnw -B -ntp -q -DskipTests package) > "$EVID/logs/empaquetar.log" 2>&1
echo $? > "$EVID/logs/empaquetar.exit"

# La aplicacion refactorizada en su propia xterm, en primer plano: es la consola de los logs
APP=$(xterm_de logs-consola)
for i in $(seq 1 90); do curl -s -o /dev/null http://localhost:8080/api-docs && break; sleep 2; done

# Verificacion sin pantalla (respuestas en JSON para readme.py), luego las capturas de la API
bash "$H/verificar.sh" "$EVID" > "$EVID/logs/verificar.log" 2>&1
capturar post-exitoso
capturar errores-api
(cd "$RUNNER_TEMP" && NODE_PATH="$RUNNER_TEMP/node_modules" node "$H/swagger.js" "$CAP") 2>&1
sleep 2
foto logs-consola                # la consola queda sola en pantalla al cerrar las otras ventanas
capturar logs-archivo
cp pedidos/logs/pedidos.log "$EVID/logs/pedidos.log" 2>/dev/null
kill "$APP" 2>/dev/null
pkill -f 'java -jar target/pedidos-0.0.1-SNAPSHOT.jar$' 2>/dev/null
sleep 2
capturar pruebas                 # al final: hace clean verify sobre el mismo proyecto
true
