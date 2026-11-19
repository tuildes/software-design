enum ErroDeEspaco: Error, Equatable {
    case naoEncontrado
    case periodoInvalido
    case usuarioNaoEncontrado
    case naoAutorizado

    var mensagem: String {
        switch self {
        case .naoEncontrado:
            return "Espaco nao encontrado"
        case .periodoInvalido:
            return "Periodo invalido"
        case .usuarioNaoEncontrado:
            return "Usuario nao encontrado"
        case .naoAutorizado:
            return "Usuario nao autorizado a cadastrar espaco"
        }
    }

    var statusHttp: Int {
        switch self {
        case .naoAutorizado:
            return 403
        case .naoEncontrado, .usuarioNaoEncontrado:
            return 404
        case .periodoInvalido:
            return 400
        }
    }
}
