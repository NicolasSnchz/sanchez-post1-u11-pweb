#!/usr/bin/env bash
# Mide la suite, levanta el codigo de partida (8081) y la aplicacion refactorizada (8080), verifica las
# respuestas, toma las capturas y arma el README con los datos medidos. Termina con error (y sin README)
# si cualquier verificacion no da lo esperado.
set -u
REPO=$PWD
H=$REPO/.github/evidencias
SALIDA=$REPO/evid
CAP=$REPO/capturas
TRABAJO=$(mktemp -d)
mkdir -p "$SALIDA/logs" "$CAP"
J17=$JAVA_HOME_17_X64
J23=$JAVA_HOME_23_X64
export JAVA_HOME=$J17 PATH="$J17/bin:$PATH"

correr() {  # nombre carpeta jdk argumentos...
    local nombre=$1 dir=$2 jdk=$3; shift 3
    (cd "$dir" && JAVA_HOME=$jdk PATH="$jdk/bin:$PATH" ./mvnw -B -ntp "$@") > "$SALIDA/logs/$nombre.log" 2>&1
    echo $? > "$SALIDA/logs/$nombre.exit"
}
extraer() {  # commit carpeta -> deja <carpeta>/pedidos con el proyecto de ese commit
    rm -rf "$2"; mkdir -p "$2"; git -C "$REPO" archive "$1" pedidos | tar -x -C "$2"
}
esperar() {  # puerto
    for i in $(seq 1 90); do curl -s -o /dev/null "http://localhost:$1/api/pedidos/0" && return 0; sleep 2; done; return 1
}

{ echo "commit: $(git rev-parse HEAD)"; "$J17/bin/java" -version; "$J23/bin/java" -version; } > "$SALIDA/entorno.txt" 2>&1
git log --format='%h %s' > "$SALIDA/historial.txt"

# 1. Cada commit compila y pasa sus pruebas por si solo
for c in $(git rev-list --reverse HEAD); do
    git cat-file -e "$c:pedidos/pom.xml" 2>/dev/null || continue
    extraer "$c" "$TRABAJO/c"
    correr "commit-${c:0:7}" "$TRABAJO/c/pedidos" "$J17" verify
    echo "${c:0:7} $(git log -1 --format=%s "$c") -> exit $(cat "$SALIDA/logs/commit-${c:0:7}.exit")" >> "$SALIDA/compilacion-por-commit.txt"
done

# 2. Suite completa con JDK 17 y con JDK 23
extraer HEAD "$TRABAJO/j17"; correr verify-jdk17 "$TRABAJO/j17/pedidos" "$J17" clean verify
cp -r "$TRABAJO/j17/pedidos/target/surefire-reports" "$SALIDA/surefire-jdk17" 2>/dev/null
extraer HEAD "$TRABAJO/j23"; correr verify-jdk23 "$TRABAJO/j23/pedidos" "$J23" clean verify

# 3. Codigo de partida (primer commit del proyecto) en el puerto 8081
PARTIDA=$(git log --reverse --format=%h --grep='^feat: proyecto Spring Boot de partida' | head -1)
echo "$PARTIDA" > "$SALIDA/partida.txt"
extraer "$PARTIDA" "$TRABAJO/partida"
correr empaquetar-partida "$TRABAJO/partida/pedidos" "$J17" -DskipTests package
(cd "$TRABAJO/partida/pedidos" && java -jar target/pedidos-0.0.1-SNAPSHOT.jar --server.port=8081) \
    > "$SALIDA/logs/app-partida.log" 2>&1 &
PID_PARTIDA=$!
esperar 8081 || echo "el codigo de partida no arranco" >> "$SALIDA/logs/errores.txt"

# 4. Capturas (la aplicacion refactorizada se empaqueta y corre en el propio repositorio: logs/ y
#    target/ estan en .gitignore): xterm reales y Chromium, todo dentro de un mismo servidor X
xvfb-run -a -s "-screen 0 1366x900x24" bash "$H/capturas.sh" "$CAP" "$TRABAJO" "$SALIDA" \
    > "$SALIDA/logs/capturas.log" 2>&1
kill "$PID_PARTIDA" 2>/dev/null
git -C "$REPO" status --short > "$SALIDA/logs/arbol-despues.txt"

# 5. Datos medidos y README (python termina con error si algo no dio lo esperado)
cp "$CAP"/*.png "$SALIDA/" 2>/dev/null
python3 "$H/readme.py" "$SALIDA" "$H/README.plantilla.md" "$REPO/README.md" 2>&1 | tee "$SALIDA/logs/readme.log"
exit "${PIPESTATUS[0]}"
