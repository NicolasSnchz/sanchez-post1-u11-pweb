package com.tienda.pedidos.exception;

import java.time.LocalDateTime;

// Cuerpo unico de error de la API: el cliente siempre recibe la misma forma, sea 400, 404 o 500
public class ApiError {

    private final int status;
    private final String error;
    private final String mensaje;
    private final String timestamp;
    private final String path;

    public ApiError(int status, String error, String mensaje, String path) {
        this.status = status;
        this.error = error;
        this.mensaje = mensaje;
        this.timestamp = LocalDateTime.now().withNano(0).toString();
        this.path = path;
    }

    public int getStatus() { return status; }
    public String getError() { return error; }
    public String getMensaje() { return mensaje; }
    public String getTimestamp() { return timestamp; }
    public String getPath() { return path; }
}
