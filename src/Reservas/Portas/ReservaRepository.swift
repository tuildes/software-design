import Foundation

protocol ReservaRepository: AnyObject {
    func salvar(_ reserva: Reserva)
    func buscarPorId(_ id: UUID) -> Reserva?
    func listarTodas() -> [Reserva]
    func listarPorEspacoEData(_ espacoId: UUID, _ data: DataLocal) -> [Reserva]
    func listarAtivasPorPeriodo(_ periodo: PeriodoHorario) -> [Reserva]
}
