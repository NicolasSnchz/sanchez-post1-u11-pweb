package com.tienda.pedidos;

import com.tienda.pedidos.dto.PedidoRequestDTO;
import com.tienda.pedidos.dto.PedidoResponseDTO;
import com.tienda.pedidos.entity.Pedido;
import com.tienda.pedidos.repository.PedidoRepository;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

// PASO INTERMEDIO de la refactorizacion: el SQL concatenado ya no existe (PedidoRepository) y la API
// ya habla con DTOs, pero el calculo del descuento y el new del notificador siguen aqui. Salen al
// servicio en el commit siguiente
@RestController
@RequestMapping("/api/pedidos")
public class PedidoController {

    private final PedidoRepository repo;

    public PedidoController(PedidoRepository repo) {
        this.repo = repo;
    }

    @PostMapping
    public PedidoResponseDTO crearPedido(@Valid @RequestBody PedidoRequestDTO dto) {
        double descuento;
        if ("VIP".equalsIgnoreCase(dto.getTipoCliente())) {
            descuento = dto.getSubtotal() * 0.15;
        } else if ("MAYORISTA".equalsIgnoreCase(dto.getTipoCliente())) {
            descuento = dto.getSubtotal() * 0.25;
        } else {
            descuento = 0.0;
        }
        double baseConDescuento = dto.getSubtotal() - descuento;
        double iva = baseConDescuento * 0.19;
        double total = baseConDescuento + iva;

        Pedido pedido = new Pedido();
        pedido.setClienteEmail(dto.getClienteEmail());
        pedido.setTipoCliente(dto.getTipoCliente().toUpperCase());
        pedido.setSubtotal(dto.getSubtotal());
        pedido.setDescuento(descuento);
        pedido.setIva(iva);
        pedido.setTotal(total);
        pedido.setEstado("CREADO");
        pedido.setNotasInternas("Pedido creado automaticamente, revisar stock antes de despachar");
        pedido.setFechaCreacion(LocalDateTime.now());
        Pedido guardado = repo.save(pedido);

        NotificacionEmailService notificador = new NotificacionEmailService();
        notificador.enviar(guardado.getClienteEmail(), "Tu pedido fue creado. Total: " + total);
        System.out.println("Pedido creado para " + guardado.getClienteEmail());

        return toResponseDTO(guardado);
    }

    @GetMapping("/{id}")
    public PedidoResponseDTO obtenerPedido(@PathVariable Long id) {
        return repo.findById(id).map(this::toResponseDTO).orElse(null);
    }

    private PedidoResponseDTO toResponseDTO(Pedido p) {
        PedidoResponseDTO dto = new PedidoResponseDTO();
        dto.setId(p.getId());
        dto.setClienteEmail(p.getClienteEmail());
        dto.setTipoCliente(p.getTipoCliente());
        dto.setSubtotal(p.getSubtotal());
        dto.setDescuento(p.getDescuento());
        dto.setIva(p.getIva());
        dto.setTotal(p.getTotal());
        dto.setEstado(p.getEstado());
        return dto;
    }
}
