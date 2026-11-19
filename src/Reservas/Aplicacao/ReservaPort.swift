import Foundation

/// Porta primária do módulo Reservas (entrada do hexágono).
protocol ReservaPort: AnyObject {
    func realizarReserva(usuarioId: UUID, espacoId: UUID, periodo: PeriodoHorario) throws -> Reserva
    func listarReservas() -> [Reserva]
}
