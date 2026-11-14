package com.tienda.pedidos.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

// DTO de entrada: solo los datos que el cliente puede enviar. id, estado, descuento, iva, total y
// notasInternas los decide el servidor, asi que no existen aqui
public class PedidoRequestDTO {

    @NotBlank(message = "El email del cliente es obligatorio")
    @Email(message = "El email del cliente no tiene un formato valido")
    private String clienteEmail;

    @NotBlank(message = "El tipo de cliente es obligatorio")
    private String tipoCliente;      // REGULAR, VIP o MAYORISTA

    // @Positive considera valido un null: sin @NotNull un pedido sin subtotal pasaria la validacion
    @NotNull(message = "El subtotal es obligatorio")
    @Positive(message = "El subtotal debe ser mayor a cero")
    private Double subtotal;

    public String getClienteEmail() { return clienteEmail; }
    public void setClienteEmail(String clienteEmail) { this.clienteEmail = clienteEmail; }
    public String getTipoCliente() { return tipoCliente; }
    public void setTipoCliente(String tipoCliente) { this.tipoCliente = tipoCliente; }
    public Double getSubtotal() { return subtotal; }
    public void setSubtotal(Double subtotal) { this.subtotal = subtotal; }
}
