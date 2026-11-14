"""Revisa que todas las mediciones den lo esperado y arma el README con los datos reales.

uso: python3 readme.py <carpeta-evid> <plantilla> <README.md de salida>
Termina con codigo 1 (y sin escribir el README) si algo no cumple.
"""
import glob
import json
import os
import sys
import xml.etree.ElementTree as ET

evid, plantilla, salida = sys.argv[1:4]
problemas = []


def leer(ruta, defecto=""):
    try:
        with open(ruta, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return defecto


def exigir(condicion, mensaje):
    if not condicion:
        problemas.append(mensaje)


def salida_de(nombre):
    return leer(f"{evid}/logs/{nombre}.exit", "sin-dato").strip()


# 1. Cada commit compila y pasa sus pruebas; suite verde con JDK 17 y 23
por_commit = leer(f"{evid}/compilacion-por-commit.txt")
exigir(por_commit.strip(), "no se midio la compilacion por commit")
for linea in por_commit.splitlines():
    exigir(linea.endswith("exit 0"), "commit que no compila o no pasa: " + linea)
for jdk in ("verify-jdk17", "verify-jdk23"):
    exigir(salida_de(jdk) == "0", f"{jdk} termino con {salida_de(jdk)}")
exigir(salida_de("empaquetar") == "0", "no se pudo empaquetar la aplicacion")

# 2. Pruebas por clase
pruebas = {}
for xml in glob.glob(f"{evid}/surefire-jdk17/TEST-*.xml"):
    raiz = ET.parse(xml).getroot()
    pruebas[raiz.get("name").rsplit(".", 1)[1]] = int(raiz.get("tests"))
    exigir(raiz.get("failures") == "0" and raiz.get("errors") == "0", f"fallos en {raiz.get('name')}")
for clase in ("EstrategiaDescuentoTest", "PedidoServiceImplTest", "PedidoControllerTest", "PedidosIntegracionTest"):
    exigir(clase in pruebas, f"no hay resultados de {clase}")

# 3. Respuestas reales de las dos versiones
try:
    r = json.loads(leer(f"{evid}/respuestas.json"))
except ValueError:
    r = {}
    problemas.append("no se pudo leer respuestas.json")


def codigo(clave):
    return r.get(clave, {}).get("codigo")


def cuerpo(clave):
    try:
        return json.loads(r.get(clave, {}).get("cuerpo", ""))
    except ValueError:
        return None


# Codigo de partida: los defectos que la guia describe, medidos
p = cuerpo("partida_post") or {}
exigir(codigo("partida_post") == 200 and p.get("notasInternas"), "partida: el POST no expuso notasInternas")
exigir(codigo("partida_get999") == 200 and r.get("partida_get999", {}).get("cuerpo") == "",
       "partida: GET 999 no respondio 200 vacio")
exigir(codigo("partida_apostrofo") == 500, "partida: el apostrofo no rompio el INSERT")

# Version refactorizada
esperado = {"vip": (15000.0, 16150.0, 101150.0), "mayorista": (25000.0, 14250.0, 89250.0),
            "regular": (0.0, 19000.0, 119000.0)}
for clave, (d, i, t) in esperado.items():
    c = cuerpo(clave) or {}
    exigir(codigo(clave) == 201, f"{clave}: codigo {codigo(clave)}")
    exigir((c.get("descuento"), c.get("iva"), c.get("total")) == (d, i, t), f"{clave}: montos {c}")
    exigir("notasInternas" not in c, f"{clave}: expone notasInternas")
exigir(codigo("apostrofo") == 201, "el apostrofo no se guardo con JPA")
exigir(codigo("get1") == 200 and "notasInternas" not in (cuerpo("get1") or {}), "GET 1 incorrecto")
lista = cuerpo("lista") or []
exigir(codigo("lista") == 200 and len(lista) >= 3 and all("notasInternas" not in x for x in lista), "lista incorrecta")
e404 = cuerpo("get999") or {}
exigir(codigo("get999") == 404 and e404.get("status") == 404 and e404.get("error") == "Not Found"
       and e404.get("mensaje") == "Pedido con id 999 no encontrado." and e404.get("path") == "/api/pedidos/999"
       and e404.get("timestamp"), f"404 incorrecto: {e404}")
e400 = cuerpo("vacio") or {}
exigir(codigo("vacio") == 400 and all(k in e400.get("mensaje", "") for k in ("clienteEmail", "tipoCliente", "subtotal")),
       f"400 de body vacio incorrecto: {e400}")
for clave in ("sin_subtotal", "id_texto", "sin_parametro"):
    exigir(codigo(clave) == 400, f"{clave}: codigo {codigo(clave)}")

# OpenAPI generado por springdoc
docs = cuerpo("api_docs") or {}
exigir(docs.get("info", {}).get("title") == "API de Pedidos", "OpenAPI sin el titulo de @OpenAPIDefinition")
rutas = docs.get("paths", {})
for ruta, metodo, codigos in (("/api/pedidos", "post", {"201", "400"}), ("/api/pedidos/{id}", "get", {"200", "400", "404"}),
                              ("/api/pedidos", "get", {"200", "400"})):
    op = rutas.get(ruta, {}).get(metodo, {})
    exigir(codigos <= set(op.get("responses", {})), f"OpenAPI {metodo} {ruta}: respuestas {list(op.get('responses', {}))}")
    exigir(op.get("tags") == ["Pedidos"] and op.get("summary"), f"OpenAPI {metodo} {ruta}: sin @Tag o @Operation")
# Cada respuesta de error con su propio ejemplo de ApiError (no el de 404 en un 400)
def ejemplo(ruta, metodo, cod):
    return json.dumps(rutas.get(ruta, {}).get(metodo, {}).get("responses", {}).get(cod, {}), ensure_ascii=False)
exigir("Bad Request" in ejemplo("/api/pedidos", "post", "400") and "Not Found" not in ejemplo("/api/pedidos", "post", "400"),
       "el 400 del POST no tiene su propio ejemplo")
exigir("Not Found" in ejemplo("/api/pedidos/{id}", "get", "404"), "el 404 del GET no tiene su ejemplo")
exigir("valor invalido" in ejemplo("/api/pedidos/{id}", "get", "400"), "el 400 del GET por id no tiene su ejemplo")
esquema = docs.get("components", {}).get("schemas", {}).get("PedidoRequestDTO", {}).get("properties", {})
exigir(esquema.get("tipoCliente", {}).get("enum") == ["REGULAR", "VIP", "MAYORISTA"], "@Schema de tipoCliente sin valores")
exigir("notasInternas" not in json.dumps(docs.get("components", {})), "el OpenAPI menciona notasInternas")

# 4. Logs: consola y archivo con el formato de logback-spring.xml, sin notasInternas
log_archivo = leer(f"{evid}/logs/pedidos.log")
for texto in ("Creando pedido: clienteEmail=", "Descuento aplicado:", "Pedido creado exitosamente con id=",
              "WARN", "no encontrado", "no tiene estrategia de descuento"):
    exigir(texto in log_archivo, f"el archivo de log no tiene '{texto}'")
exigir("notasInternas" not in log_archivo and "revisar stock" not in log_archivo, "el log contiene notasInternas")

# 5. Capturas y arbol limpio
for png in ("partida-antes", "compilacion", "post-exitoso", "errores-api", "logs-consola", "logs-archivo",
            "pruebas", "swagger-ui", "swagger-post", "swagger-get"):
    ruta = os.path.join(os.path.dirname(salida), "capturas", png + ".png")
    exigir(os.path.isfile(ruta) and os.path.getsize(ruta) > 5000, f"falta o esta vacia la captura {png}.png")
# solo pueden aparecer capturas/ y evid/ (nuevas o modificadas si se estan regenerando)
sobrantes = [l for l in leer(f"{evid}/logs/arbol-despues.txt").splitlines()
             if not l[3:].startswith(("capturas/", "evid/"))]
exigir(not sobrantes, "quedaron cambios en el arbol: " + "; ".join(sobrantes))

datos = {
    "T_ESTRATEGIA": str(pruebas.get("EstrategiaDescuentoTest", "?")),
    "T_SERVICIO": str(pruebas.get("PedidoServiceImplTest", "?")),
    "T_CONTROLADOR": str(pruebas.get("PedidoControllerTest", "?")),
    "T_INTEGRACION": str(pruebas.get("PedidosIntegracionTest", "?")),
    "T_TOTAL": str(sum(pruebas.values())),
    "PARTIDA": leer(f"{evid}/partida.txt").strip(),
}
texto = leer(plantilla)
for clave, valor in datos.items():
    texto = texto.replace("{{" + clave + "}}", valor)
if "{{" in texto:
    problemas.append("quedaron marcadores sin llenar: " + texto[texto.index("{{"):texto.index("{{") + 30])

print(json.dumps(datos, ensure_ascii=False, indent=2))
if problemas:
    print("\nNO se publica el README:")
    for p in problemas:
        print(" -", p)
    sys.exit(1)
with open(salida, "w", encoding="utf-8") as f:
    f.write(texto)
print("\nREADME generado:", salida)
