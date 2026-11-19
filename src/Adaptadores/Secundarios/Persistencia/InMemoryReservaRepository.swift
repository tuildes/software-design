import Foundation

final class InMemoryReservaRepository: ReservaRepository {
    private var itens: [UUID: Reserva] = [:]

    func salvar(_ reserva: Reserva) {
        itens[reserva.id] = reserva
    }

    func buscarPorId(_ id: UUID) -> Reserva? {
        itens[id]
    }

    func listarTodas() -> [Reserva] {
        Array(itens.values)
    }

    func listarPorEspacoEData(_ espacoId: UUID, _ data: DataLocal) -> [Reserva] {
        itens.values.filter { $0.espacoEsportivo.id == espacoId && $0.periodoHorario.data == data }
    }

    func listarAtivasPorPeriodo(_ periodo: PeriodoHorario) -> [Reserva] {
        itens.values.filter { $0.conflitaCom(periodo) }
    }
}
