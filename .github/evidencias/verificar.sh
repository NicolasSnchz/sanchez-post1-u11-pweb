#!/usr/bin/env bash
# Guarda en <evid>/respuestas.json las respuestas reales (codigo y cuerpo) de las dos versiones
# uso: verificar.sh <carpeta-evid>
EVID=$1
N=http://localhost:8080/api/pedidos
P=http://localhost:8081/api/pedidos
JSONH='Content-Type: application/json'
pedir() {  # clave metodo url [cuerpo] -> agrega {"clave": {"codigo": .., "cuerpo": ..}}
    local clave=$1 metodo=$2 url=$3 cuerpo=${4:-}
    local r
    if [ -n "$cuerpo" ]; then r=$(curl -s -X "$metodo" "$url" -H "$JSONH" -d "$cuerpo" -w '\n%{http_code}')
    else r=$(curl -s -X "$metodo" "$url" -w '\n%{http_code}'); fi
    jq -n --arg k "$clave" --arg c "$(echo "$r" | tail -1)" --arg b "$(echo "$r" | sed '$d')" '{($k): {codigo: ($c|tonumber), cuerpo: $b}}'
}
{
  # Codigo de partida
  pedir partida_post POST "$P" '{"clienteEmail":"ana@correo.com","tipoCliente":"VIP","subtotal":100000}'
  pedir partida_get999 GET "$P/999"
  pedir partida_apostrofo POST "$P" "{\"clienteEmail\":\"o'brien@correo.com\",\"tipoCliente\":\"VIP\",\"subtotal\":100000}"
  # Version refactorizada
  pedir vip POST "$N" '{"clienteEmail":"ana@correo.com","tipoCliente":"VIP","subtotal":100000}'
  pedir mayorista POST "$N" '{"clienteEmail":"ana@correo.com","tipoCliente":"MAYORISTA","subtotal":100000}'
  pedir regular POST "$N" '{"clienteEmail":"ana@correo.com","tipoCliente":"REGULAR","subtotal":100000}'
  pedir apostrofo POST "$N" "{\"clienteEmail\":\"o'brien@correo.com\",\"tipoCliente\":\"VIP\",\"subtotal\":100000}"
  pedir get1 GET "$N/1"
  pedir lista GET "$N?clienteEmail=ana@correo.com"
  pedir get999 GET "$N/999"
  pedir vacio POST "$N" '{}'
  pedir sin_subtotal POST "$N" '{"clienteEmail":"ana@correo.com","tipoCliente":"VIP"}'
  pedir id_texto GET "$N/abc"
  pedir sin_parametro GET "$N"
  pedir api_docs GET "http://localhost:8080/api-docs"
} | jq -s 'add' > "$EVID/respuestas.json"
jq 'map_values(.codigo)' "$EVID/respuestas.json"
