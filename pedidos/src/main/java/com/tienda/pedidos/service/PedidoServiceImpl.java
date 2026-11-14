package com.tienda.pedidos.service;

import com.tienda.pedidos.dto.PedidoRequestDTO;
import com.tienda.pedidos.dto.PedidoResponseDTO;
import com.tienda.pedidos.entity.Pedido;
import com.tienda.pedidos.exception.RecursoNoEncontradoException;
import com.tienda.pedidos.repository.PedidoRepository;
import com.tienda.pedidos.strategy.EstrategiaDescuento;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@Service
public class PedidoServiceImpl implements PedidoService {

    private static final double TASA_IVA = 0.19;

    private final PedidoRepository repo;
    private final NotificacionService notificador;
    private final Map<String, EstrategiaDescuento> estrategias;

    // Todas las dependencias llegan por constructor (DIP): ningun new de un colaborador. Spring arma el
    // mapa con cada EstrategiaDescuento usando el nombre del bean como llave (REGULAR, VIP, MAYORISTA)
    public PedidoServiceImpl(PedidoRepository repo,
                             NotificacionService notificador,
                             Map<String, EstrategiaDescuento> estrategias) {
        this.repo = repo;
        this.notificador = notificador;
        this.estrategias = estrategias;
    }

    @Override
    public PedidoResponseDTO crear(PedidoRequestDTO dto) {
        EstrategiaDescuento estrategia = estrategias.getOrDefault(
            dto.getTipoCliente().toUpperCase(), estrategias.get("REGULAR"));
        double descuento = estrategia.calcularDescuento(dto.getSubtotal());
        return guardar(dto, descuento);
    }

    @Override
    public PedidoResponseDTO buscarPorId(Long id) {
        Pedido p = repo.findById(id)
            .orElseThrow(() -> new RecursoNoEncontradoException("Pedido", id));
        return toResponseDTO(p);
    }

    @Override
    public List<PedidoResponseDTO> listarPorCliente(String clienteEmail) {
        return repo.findByClienteEmail(clienteEmail).stream().map(this::toResponseDTO).toList();
    }

    private PedidoResponseDTO guardar(PedidoRequestDTO dto, double descuentoCalculado) {
        double descuento = redondear(descuentoCalculado);
        double baseConDescuento = dto.getSubtotal() - descuento;
        double iva = redondear(baseConDescuento * TASA_IVA);
        double total = redondear(baseConDescuento + iva);

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
        notificador.enviarConfirmacion(guardado.getClienteEmail(), guardado.getTotal());
        return toResponseDTO(guardado);
    }

    // Montos de dinero con dos decimales: con double, un subtotal como 123456.78 daria un total
    // de 124876.53297
    private static double redondear(double valor) {
        return BigDecimal.valueOf(valor).setScale(2, RoundingMode.HALF_UP).doubleValue();
    }

    // Mapeo explicito entidad -> DTO: notasInternas y fechaCreacion no se copian
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
