import Foundation

final class ReservaService {
    private let reservaRepository: ReservaRepository
    private let espacoRepository: EspacoEsportivoRepository
    private let usuarioRepository: UsuarioRepository
    private let notificador: Notificador

    init(
        reservaRepository: ReservaRepository,
        espacoRepository: EspacoEsportivoRepository,
        usuarioRepository: UsuarioRepository,
        notificador: Notificador
    ) {
        self.reservaRepository = reservaRepository
        self.espacoRepository = espacoRepository
        self.usuarioRepository = usuarioRepository
        self.notificador = notificador
    }

    func realizarReserva(usuarioId: UUID, espacoId: UUID, periodo: PeriodoHorario) throws -> Reserva {
        if !periodo.ehValido() {
            throw ErroDeReserva.periodoInvalido
        }

        guard let usuario = usuarioRepository.buscarPorId(usuarioId) else {
            throw ErroDeReserva.usuarioNaoEncontrado
        }
        if !usuario.podeRealizarReserva() {
            throw ErroDeReserva.usuarioNaoAutorizado
        }

        guard let espaco = espacoRepository.buscarPorId(espacoId) else {
            throw ErroDeReserva.espacoNaoEncontrado
        }
        let disponivel = espaco.estaDisponivelParaReserva(periodo)
        let atende = espaco.atendeRestricoes(usuario, periodo)
        if !disponivel || !atende {
            throw ErroDeReserva.espacoIndisponivelOuRestricaoViolada
        }

        let existentes = reservaRepository.listarPorEspacoEData(espacoId, periodo.data)
        for existente in existentes {
            if existente.conflitaCom(periodo) {
                throw ErroDeReserva.horarioJaReservado
            }
        }

        let novaReserva = Reserva(espacoEsportivo: espaco, usuario: usuario, periodoHorario: periodo)
        reservaRepository.salvar(novaReserva)
        notificador.notificar(
            destinatario: usuario.email,
            assunto: "Reserva Confirmada",
            mensagem: descrever(novaReserva)
        )
        return novaReserva
    }

    func listarReservas() -> [Reserva] {
        reservaRepository.listarTodas()
    }
}

private func descrever(_ reserva: Reserva) -> String {
    let periodo = reserva.periodoHorario
    return "id=\(reserva.id.uuidString) espaco=\(reserva.espacoEsportivo.nome) data=\(periodo.data.texto()) inicio=\(periodo.horaInicio.texto()) fim=\(periodo.horaFim.texto())"
}
