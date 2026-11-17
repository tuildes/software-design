import Foundation
import LocacaoEspacos

private struct ErroCli: Error {
    let mensagem: String
}

@main
struct LocacaoEspacosApp {
    static func main() {
        let codigo = Cli.executar(Array(CommandLine.arguments.dropFirst()))
        if codigo != 0 {
            exit(codigo)
        }
    }
}

private struct ItemSessao {
    let id: String
    let nome: String
}

private enum Cli {
    private static var usuariosSessao: [ItemSessao] = []
    private static var espacosSessao: [ItemSessao] = []

    static func executar(_ args: [String]) -> Int32 {
        if args.contains("--ajuda") || args.contains("-h") {
            print(ajuda)
            return 0
        }
        if args.isEmpty {
            print(ajuda)
            return 1
        }
        do {
            switch args[0] {
            case "servidor":
                return try servidor(Array(args.dropFirst()))
            case "cli":
                return try menu(Array(args.dropFirst()))
            case "usuario":
                return try usuario(Array(args.dropFirst()))
            case "espaco":
                return try espaco(Array(args.dropFirst()))
            case "reserva":
                return try reserva(Array(args.dropFirst()))
            default:
                print("Comando desconhecido: \(args[0])")
                print(ajuda)
                return 1
            }
        } catch let erro as ErroCli {
            print(erro.mensagem)
            return 1
        } catch let erro as ErroDeArranque {
            print("Erro: \(erro.description)")
            return 1
        } catch {
            print("Erro: \(error)")
            return 1
        }
    }

    private static func servidor(_ args: [String]) throws -> Int32 {
        let mapa = try valores(args)
        try exigir(mapa, ["--porta", "--notificador", "--persistencia", "--banco"])
        let portaTexto = mapa["--porta"] ?? "8080"
        guard let porta = UInt16(portaTexto), porta > 0 else {
            throw ErroCli(mensagem: "Porta invalida")
        }
        let notificador = try modoNotificador(mapa["--notificador"] ?? "email")
        let persistencia = try modoPersistencia(mapa)
        try iniciarServidor(porta: porta, persistencia: persistencia, notificador: notificador)
        return 0
    }

    private static func menu(_ args: [String]) throws -> Int32 {
        let mapa = try valores(args)
        try exigir(mapa, ["--servidor"])
        let servidor = mapa["--servidor"] ?? "http://127.0.0.1:8080"
        print("Locacao de Espacos Esportivos")
        print("Servidor: \(servidor)")
        print("Suba o servidor antes de usar as opcoes.")
        while true {
            print("")
            print("1. Cadastrar usuario")
            print("2. Cadastrar espaco")
            print("3. Criar reserva")
            print("4. Ver reservas")
            print("0. Sair")
            print("Opcao: ", terminator: "")
            fflush(stdout)
            guard let escolha = lerLinha()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return 0
            }
            switch escolha {
            case "1":
                _ = cadastrarUsuarioInterativo(servidor: servidor)
            case "2":
                _ = cadastrarEspacoInterativo(servidor: servidor)
            case "3":
                _ = criarReservaInterativa(servidor: servidor)
            case "4":
                _ = listarReservasInterativo(servidor: servidor)
            case "0":
                return 0
            default:
                print("Opcao invalida.")
            }
        }
    }

    private static func cadastrarUsuarioInterativo(servidor: String) -> Int32 {
        print("--- Cadastrar usuario ---")
        guard let nome = pedir("Nome"),
              let email = pedir("Email"),
              let telefone = pedir("Telefone") else {
            print("Cadastro cancelado.")
            return 1
        }
        guard let perfil = pedirPerfil() else {
            print("Perfil invalido. Use CLIENTE ou ADMIN.")
            return 1
        }
        let codigo = enviar(
            metodo: "POST",
            caminho: "/api/v1/usuarios",
            campos: [
                "nome": nome,
                "email": email,
                "telefone": telefone,
                "perfil": perfil,
            ],
            servidor: servidor
        )
        if codigo == 0, let id = ultimoIdEnviado {
            usuariosSessao.append(ItemSessao(id: id, nome: nome))
        }
        return codigo
    }

    private static func cadastrarEspacoInterativo(servidor: String) -> Int32 {
        print("--- Cadastrar espaco ---")
        guard let nome = pedir("Nome"),
              let tipo = pedir("Tipo"),
              let capacidadeTexto = pedir("Capacidade"),
              let capacidade = Int(capacidadeTexto), capacidade > 0 else {
            print("Cadastro cancelado ou capacidade invalida.")
            return 1
        }
        let codigo = enviar(
            metodo: "POST",
            caminho: "/api/v1/espacos",
            campos: [
                "nome": nome,
                "tipo": tipo,
                "capacidade": capacidade,
            ],
            servidor: servidor
        )
        if codigo == 0, let id = ultimoIdEnviado {
            espacosSessao.append(ItemSessao(id: id, nome: nome))
        }
        return codigo
    }

    private static func criarReservaInterativa(servidor: String) -> Int32 {
        print("--- Criar reserva ---")
        guard let usuario = pedirReferencia(
            rotulo: "Usuario",
            itens: usuariosSessao,
            dica: "numero da sessao ou UUID"
        ),
              let espaco = pedirReferencia(
                rotulo: "Espaco",
                itens: espacosSessao,
                dica: "numero da sessao ou UUID"
              ),
              let data = pedir("Data (AAAA-MM-DD)"),
              let inicio = pedir("Inicio (HH:MM)"),
              let fim = pedir("Fim (HH:MM)") else {
            print("Reserva cancelada.")
            return 1
        }
        return enviar(
            metodo: "POST",
            caminho: "/api/v1/reservas",
            campos: [
                "usuarioId": usuario,
                "espacoId": espaco,
                "data": data,
                "horaInicio": inicio,
                "horaFim": fim,
            ],
            servidor: servidor
        )
    }

    private static func listarReservasInterativo(servidor: String) -> Int32 {
        print("--- Reservas ---")
        let resultado = requisitar(metodo: "GET", caminho: "/api/v1/reservas", campos: nil, servidor: servidor)
        if let falha = resultado.falha {
            print("Erro de conexao: \(falha)")
            return 1
        }
        imprimirResposta(status: resultado.status, texto: resultado.texto, listaReservas: true)
        return (200..<300).contains(resultado.status) ? 0 : 1
    }

    private static var ultimoIdEnviado: String?

    private static func usuario(_ args: [String]) throws -> Int32 {
        guard args.first == "cadastrar" else {
            throw ErroCli(mensagem: "Use: usuario cadastrar --nome --email --telefone")
        }
        let mapa = try valores(Array(args.dropFirst()))
        try exigir(mapa, ["--nome", "--email", "--telefone", "--perfil", "--servidor"])
        let nome = try obrigatorio(mapa, "--nome")
        let email = try obrigatorio(mapa, "--email")
        let telefone = try obrigatorio(mapa, "--telefone")
        var campos: [String: Any] = ["nome": nome, "email": email, "telefone": telefone]
        if let perfil = mapa["--perfil"] {
            campos["perfil"] = perfil.uppercased()
        }
        return enviar(metodo: "POST", caminho: "/api/v1/usuarios", campos: campos, servidor: mapa["--servidor"])
    }

    private static func espaco(_ args: [String]) throws -> Int32 {
        guard args.first == "cadastrar" else {
            throw ErroCli(mensagem: "Use: espaco cadastrar --nome --tipo --capacidade")
        }
        let mapa = try valores(Array(args.dropFirst()))
        try exigir(mapa, ["--nome", "--tipo", "--capacidade", "--servidor"])
        let nome = try obrigatorio(mapa, "--nome")
        let tipo = try obrigatorio(mapa, "--tipo")
        let capacidadeTexto = try obrigatorio(mapa, "--capacidade")
        guard let capacidade = Int(capacidadeTexto), capacidade > 0 else {
            throw ErroCli(mensagem: "Capacidade invalida")
        }
        let campos: [String: Any] = ["nome": nome, "tipo": tipo, "capacidade": capacidade]
        return enviar(metodo: "POST", caminho: "/api/v1/espacos", campos: campos, servidor: mapa["--servidor"])
    }

    private static func reserva(_ args: [String]) throws -> Int32 {
        guard let subcomando = args.first else {
            throw ErroCli(mensagem: "Use: reserva criar ... ou reserva listar")
        }
        switch subcomando {
        case "criar":
            let mapa = try valores(Array(args.dropFirst()))
            try exigir(mapa, ["--usuario", "--espaco", "--data", "--inicio", "--fim", "--servidor"])
            let campos: [String: Any] = [
                "usuarioId": try obrigatorio(mapa, "--usuario"),
                "espacoId": try obrigatorio(mapa, "--espaco"),
                "data": try obrigatorio(mapa, "--data"),
                "horaInicio": try obrigatorio(mapa, "--inicio"),
                "horaFim": try obrigatorio(mapa, "--fim"),
            ]
            return enviar(metodo: "POST", caminho: "/api/v1/reservas", campos: campos, servidor: mapa["--servidor"])
        case "listar":
            let mapa = try valores(Array(args.dropFirst()))
            try exigir(mapa, ["--servidor"])
            return listarReservasInterativo(servidor: mapa["--servidor"] ?? "http://127.0.0.1:8080")
        default:
            throw ErroCli(mensagem: "Use: reserva criar ... ou reserva listar")
        }
    }

    private static func enviar(metodo: String, caminho: String, campos: [String: Any]?, servidor: String?) -> Int32 {
        ultimoIdEnviado = nil
        let resultado = requisitar(metodo: metodo, caminho: caminho, campos: campos, servidor: servidor)
        if let falha = resultado.falha {
            print("Erro de conexao: \(falha)")
            return 1
        }
        if (200..<300).contains(resultado.status),
           let dados = resultado.texto.data(using: .utf8),
           let objeto = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
           let id = objeto["id"] as? String {
            ultimoIdEnviado = id
        }
        imprimirResposta(status: resultado.status, texto: resultado.texto, listaReservas: false)
        return (200..<300).contains(resultado.status) ? 0 : 1
    }

    private static func imprimirResposta(status: Int, texto: String, listaReservas: Bool) {
        if let mensagem = mensagemDeErro(texto) {
            print("\(status) - \(mensagem)")
            return
        }
        print(status)
        if listaReservas && status == 200 {
            print(formatarListaReservas(texto))
        } else {
            print(formatar(texto))
        }
    }

    private static func mensagemDeErro(_ texto: String) -> String? {
        guard let dados = texto.data(using: .utf8),
              let objeto = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let mensagem = objeto["mensagem"] as? String else {
            return nil
        }
        return mensagem
    }

    private static func pedirPerfil() -> String? {
        let opcoes = "CLIENTE | ADMIN"
        guard let bruto = pedir("Perfil (\(opcoes))", padrao: "CLIENTE")?.uppercased() else {
            return nil
        }
        switch bruto {
        case "CLIENTE", "ADMIN":
            return bruto
        default:
            return nil
        }
    }

    private static func pedirReferencia(rotulo: String, itens: [ItemSessao], dica: String) -> String? {
        if !itens.isEmpty {
            print("\(rotulo)s desta sessao:")
            for (indice, item) in itens.enumerated() {
                print("  \(indice + 1). \(item.nome) (\(item.id))")
            }
        }
        guard let bruto = pedir("\(rotulo) (\(dica))") else {
            return nil
        }
        if let numero = Int(bruto), numero >= 1, numero <= itens.count {
            return itens[numero - 1].id
        }
        return bruto.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func requisitar(
        metodo: String,
        caminho: String,
        campos: [String: Any]?,
        servidor: String?
    ) -> (status: Int, texto: String, falha: String?) {
        var base = servidor ?? "http://127.0.0.1:8080"
        while base.hasSuffix("/") {
            base.removeLast()
        }
        guard let url = URL(string: base + caminho) else {
            return (0, "", "URL invalida")
        }
        var pedido = URLRequest(url: url)
        pedido.httpMethod = metodo
        pedido.timeoutInterval = 10
        if let campos {
            guard let corpo = try? JSONSerialization.data(withJSONObject: campos) else {
                return (0, "", "Requisicao invalida")
            }
            pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
            pedido.httpBody = corpo
        }
        let fila = OperationQueue()
        let sessao = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: fila)
        let semaforo = DispatchSemaphore(value: 0)
        var status = 0
        var texto = ""
        var falha: String?
        sessao.dataTask(with: pedido) { dados, resposta, erro in
            if let erro {
                falha = erro.localizedDescription
            } else {
                status = (resposta as? HTTPURLResponse)?.statusCode ?? 0
                texto = String(data: dados ?? Data(), encoding: .utf8) ?? ""
            }
            semaforo.signal()
        }.resume()
        semaforo.wait()
        sessao.finishTasksAndInvalidate()
        return (status, texto, falha)
    }

    private static func pedir(_ rotulo: String, padrao: String? = nil) -> String? {
        if let padrao {
            print("\(rotulo) (\(padrao)): ", terminator: "")
        } else {
            print("\(rotulo): ", terminator: "")
        }
        fflush(stdout)
        guard let linha = lerLinha()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        if linha.isEmpty {
            return padrao
        }
        return linha
    }

    private static func lerLinha() -> String? {
        readLine(strippingNewline: true)
    }

    private static func modoNotificador(_ nome: String) throws -> ModoNotificador {
        switch nome {
        case "email":
            return .email
        case "fake":
            return .fake
        default:
            throw ErroCli(mensagem: "Notificador desconhecido: \(nome). Use email ou fake.")
        }
    }

    private static func modoPersistencia(_ mapa: [String: String]) throws -> ModoPersistencia {
        switch mapa["--persistencia"] ?? "sqlite" {
        case "memoria":
            return .memoria
        case "sqlite":
            return .sqlite(caminho: mapa["--banco"] ?? "locacao.sqlite")
        case let outro:
            throw ErroCli(mensagem: "Persistencia desconhecida: \(outro). Use sqlite ou memoria.")
        }
    }

    private static func valores(_ args: [String]) throws -> [String: String] {
        var mapa: [String: String] = [:]
        var indice = 0
        while indice < args.count {
            let atual = args[indice]
            guard atual.hasPrefix("--") else {
                throw ErroCli(mensagem: "Argumento invalido: \(atual)")
            }
            guard indice + 1 < args.count, !args[indice + 1].hasPrefix("--") else {
                throw ErroCli(mensagem: "Valor ausente para \(atual)")
            }
            mapa[atual] = args[indice + 1]
            indice += 2
        }
        return mapa
    }

    private static func exigir(_ mapa: [String: String], _ chaves: Set<String>) throws {
        if let chave = Set(mapa.keys).subtracting(chaves).first {
            throw ErroCli(mensagem: "Argumento desconhecido: \(chave)")
        }
    }

    private static func obrigatorio(_ mapa: [String: String], _ chave: String) throws -> String {
        guard let valor = mapa[chave], !valor.isEmpty else {
            throw ErroCli(mensagem: "Informe \(chave)")
        }
        return valor
    }

    private static func formatar(_ texto: String) -> String {
        guard let dados = texto.data(using: .utf8),
              let objeto = try? JSONSerialization.jsonObject(with: dados),
              let bonito = try? JSONSerialization.data(withJSONObject: objeto, options: [.prettyPrinted, .sortedKeys]),
              let formatado = String(data: bonito, encoding: .utf8) else {
            return texto
        }
        return formatado
    }

    private static func formatarListaReservas(_ texto: String) -> String {
        guard let dados = texto.data(using: .utf8),
              let itens = try? JSONSerialization.jsonObject(with: dados) as? [[String: Any]] else {
            return formatar(texto)
        }
        if itens.isEmpty {
            return "Nenhuma reserva encontrada."
        }
        var linhas: [String] = []
        for (indice, item) in itens.enumerated() {
            let id = item["id"] as? String ?? "-"
            let usuario = item["usuarioNome"] as? String ?? (item["usuarioId"] as? String ?? "-")
            let espaco = item["espacoNome"] as? String ?? (item["espacoId"] as? String ?? "-")
            let data = item["data"] as? String ?? "-"
            let inicio = item["horaInicio"] as? String ?? "-"
            let fim = item["horaFim"] as? String ?? "-"
            let status = item["status"] as? String ?? "-"
            linhas.append("\(indice + 1). [\(status)] \(espaco) | \(usuario) | \(data) \(inicio)-\(fim)")
            linhas.append("   id: \(id)")
        }
        return linhas.joined(separator: "\n")
    }

    private static let ajuda = """
    Locacao de Espacos Esportivos

    Uso:
      locacao-espacos servidor [--porta 8080] [--notificador email|fake] [--persistencia sqlite|memoria] [--banco locacao.sqlite]
      locacao-espacos cli [--servidor URL]
      locacao-espacos usuario cadastrar --nome NOME --email EMAIL --telefone TELEFONE [--perfil CLIENTE|ADMIN] [--servidor URL]
      locacao-espacos espaco cadastrar --nome NOME --tipo TIPO --capacidade N [--servidor URL]
      locacao-espacos reserva criar --usuario UUID --espaco UUID --data AAAA-MM-DD --inicio HH:MM --fim HH:MM [--servidor URL]
      locacao-espacos reserva listar [--servidor URL]

    O cliente envia HTTP/JSON ao servidor. Suba o servidor antes dos outros comandos.
    O modo cli abre um menu interativo: cadastrar usuario, cadastrar espaco, criar reserva e ver reservas.
    Trocar --notificador email|fake ou --persistencia sqlite|memoria muda so o tipo concreto.
    """
}
