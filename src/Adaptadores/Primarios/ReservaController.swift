import Foundation

final class ReservaController {
    private let reservaPort: ReservaPort

    init(reservaPort: ReservaPort) {
        self.reservaPort = reservaPort
    }

    func criarReserva(corpo: Data) -> Resposta {
        guard let objeto = objetoJson(corpo) else {
            return respostaDeErro(400, "Requisicao invalida: JSON malformado")
        }
        guard let usuarioBruto = textoJson(objeto["usuarioId"]),
              let usuarioId = uuidLimpo(usuarioBruto) else {
            return respostaDeErro(400, "Requisicao invalida: usuarioId")
        }
        guard let espacoBruto = textoJson(objeto["espacoId"]),
              let espacoId = uuidLimpo(espacoBruto) else {
            return respostaDeErro(400, "Requisicao invalida: espacoId")
        }
        guard let dataBruta = textoJson(objeto["data"]),
              let data = DataLocal.interpretar(dataBruta) else {
            return respostaDeErro(400, "Requisicao invalida: data (use AAAA-MM-DD)")
        }
        guard let inicioBruto = textoJson(objeto["horaInicio"]),
              let inicio = HoraLocal.interpretar(inicioBruto) else {
            return respostaDeErro(400, "Requisicao invalida: horaInicio (use HH:MM)")
        }
        guard let fimBruto = textoJson(objeto["horaFim"]),
              let fim = HoraLocal.interpretar(fimBruto) else {
            return respostaDeErro(400, "Requisicao invalida: horaFim (use HH:MM)")
        }
        let periodo = PeriodoHorario(data: data, horaInicio: inicio, horaFim: fim)
        if !periodo.ehValido() {
            return respostaDeErro(400, "Periodo invalido")
        }
        do {
            let reserva = try reservaPort.realizarReserva(usuarioId: usuarioId, espacoId: espacoId, periodo: periodo)
            return Resposta(status: 201, corpo: json(resumo(reserva)))
        } catch let erro as ErroDeReserva {
            return respostaDeErro(erro.statusHttp, erro.mensagem)
        } catch {
            print("Erro: \(error)")
            return respostaDeErro(500, "Erro interno")
        }
    }

    func listarReservas() -> Resposta {
        let itens = reservaPort.listarReservas().map(resumo)
        return Resposta(status: 200, corpo: json(itens))
    }
}

private func resumo(_ reserva: Reserva) -> [String: Any] {
    [
        "id": reserva.id.uuidString,
        "usuarioId": reserva.usuario.id.uuidString,
        "usuarioNome": reserva.usuario.nome,
        "espacoId": reserva.espacoEsportivo.id.uuidString,
        "espacoNome": reserva.espacoEsportivo.nome,
        "data": reserva.periodoHorario.data.texto(),
        "horaInicio": reserva.periodoHorario.horaInicio.texto(),
        "horaFim": reserva.periodoHorario.horaFim.texto(),
        "status": reserva.status.rawValue,
    ]
}
