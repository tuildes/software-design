import Foundation

final class Reserva {
    let id: UUID
    let espacoEsportivo: EspacoEsportivo
    let usuario: Usuario
    let periodoHorario: PeriodoHorario
    private(set) var status: StatusReserva

    init(
        id: UUID = UUID(),
        espacoEsportivo: EspacoEsportivo,
        usuario: Usuario,
        periodoHorario: PeriodoHorario,
        status: StatusReserva = .confirmada
    ) {
        self.id = id
        self.espacoEsportivo = espacoEsportivo
        self.usuario = usuario
        self.periodoHorario = periodoHorario
        self.status = status
    }

    func cancelar() {
        status = .cancelada
    }

    func estaAtiva() -> Bool {
        status == .confirmada
    }

    func conflitaCom(_ outroPeriodo: PeriodoHorario) -> Bool {
        estaAtiva() && periodoHorario.sobrepoe(outroPeriodo)
    }
}
