enum ErroDeReserva: Error, Equatable {
    case usuarioNaoEncontrado
    case usuarioNaoAutorizado
    case espacoNaoEncontrado
    case espacoIndisponivelOuRestricaoViolada
    case horarioJaReservado
    case periodoInvalido

    var mensagem: String {
        switch self {
        case .usuarioNaoEncontrado:
            return "Usuario nao encontrado"
        case .usuarioNaoAutorizado:
            return "Usuario nao autorizado a reservar"
        case .espacoNaoEncontrado:
            return "Espaco nao encontrado"
        case .espacoIndisponivelOuRestricaoViolada:
            return "Espaco indisponivel ou restricao violada"
        case .horarioJaReservado:
            return "Reserva invalida: horario ja reservado"
        case .periodoInvalido:
            return "Periodo invalido"
        }
    }

    var statusHttp: Int {
        switch self {
        case .usuarioNaoAutorizado:
            return 403
        case .espacoIndisponivelOuRestricaoViolada, .horarioJaReservado:
            return 409
        case .usuarioNaoEncontrado, .espacoNaoEncontrado:
            return 404
        case .periodoInvalido:
            return 400
        }
    }
}
