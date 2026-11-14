package com.tienda.pedidos;

// CODIGO DE PARTIDA (sin refactorizar): clase concreta, sin interfaz, que el controller crea con new
public class NotificacionEmailService {

    public void enviar(String destinatario, String mensaje) {
        // simulacion de envio de correo
        System.out.println("Correo a " + destinatario + ": " + mensaje);
    }
}
