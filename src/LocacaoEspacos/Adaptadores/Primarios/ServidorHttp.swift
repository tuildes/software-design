import Darwin
import Foundation

final class ServidorHttp {
    private let porta: UInt16
    private let usuarios: UsuarioController
    private let espacos: EspacoEsportivoController
    private let reservas: ReservaController
    private let estado = NSLock()
    private var continuar = true
    private var descritor: Int32 = -1

    init(porta: UInt16, usuarios: UsuarioController, espacos: EspacoEsportivoController, reservas: ReservaController) {
        self.porta = porta
        self.usuarios = usuarios
        self.espacos = espacos
        self.reservas = reservas
    }

    func iniciar() throws {
        _ = signal(SIGPIPE, SIG_IGN)
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ErroExterno(description: "nao foi possivel abrir o socket")
        }
        estado.lock()
        descritor = fd
        estado.unlock()
        defer {
            estado.lock()
            let atual = descritor
            descritor = -1
            estado.unlock()
            if atual >= 0 {
                close(atual)
            }
        }

        var reuso: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuso, socklen_t(MemoryLayout.size(ofValue: reuso)))

        var endereco = sockaddr_in()
        endereco.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        endereco.sin_family = sa_family_t(AF_INET)
        endereco.sin_port = porta.bigEndian
        guard inet_pton(AF_INET, "127.0.0.1", &endereco.sin_addr) == 1 else {
            throw ErroExterno(description: "endereco local invalido")
        }
        let ligado = withUnsafePointer(to: endereco) { ponteiro in
            ponteiro.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddr in
                bind(fd, sockaddr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard ligado == 0 else {
            throw ErroExterno(description: "nao foi possivel escutar a porta \(porta): \(String(cString: strerror(errno)))")
        }
        guard listen(fd, 32) == 0 else {
            throw ErroExterno(description: "nao foi possivel escutar a porta \(porta): \(String(cString: strerror(errno)))")
        }
        print("Servidor HTTP em http://127.0.0.1:\(porta)")

        while deveContinuar() {
            var clienteEndereco = sockaddr_in()
            var tamanho = socklen_t(MemoryLayout<sockaddr_in>.size)
            let cliente = withUnsafeMutablePointer(to: &clienteEndereco) { ponteiro -> Int32 in
                ponteiro.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddr in
                    accept(fd, sockaddr, &tamanho)
                }
            }
            if cliente < 0 {
                if deveContinuar() {
                    continue
                }
                break
            }
            atender(cliente)
            close(cliente)
        }
    }

    func parar() {
        estado.lock()
        continuar = false
        let fd = descritor
        descritor = -1
        estado.unlock()
        if fd >= 0 {
            close(fd)
        }
    }

    private func deveContinuar() -> Bool {
        estado.lock()
        defer { estado.unlock() }
        return continuar
    }

    private func atender(_ fd: Int32) {
        var semSinal: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &semSinal, socklen_t(MemoryLayout.size(ofValue: semSinal)))
        var tempo = timeval(tv_sec: 5, tv_usec: 0)
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tempo, socklen_t(MemoryLayout.size(ofValue: tempo)))
        guard let requisicao = lerRequisicao(fd) else { return }
        let resposta = rotear(metodo: requisicao.metodo, caminho: requisicao.caminho, corpo: requisicao.corpo)
        print("\(requisicao.metodo) \(requisicao.caminho) -> \(resposta.status)")
        escrever(fd, resposta)
    }

    private func rotear(metodo: String, caminho: String, corpo: Data) -> Resposta {
        if metodo == "POST" && caminho == "/api/v1/usuarios" {
            return usuarios.cadastrarUsuario(corpo: corpo)
        }
        if metodo == "POST" && caminho == "/api/v1/espacos" {
            return espacos.cadastrarEspaco(corpo: corpo)
        }
        if metodo == "POST" && caminho == "/api/v1/reservas" {
            return reservas.criarReserva(corpo: corpo)
        }
        if metodo == "GET" && caminho == "/api/v1/reservas" {
            return reservas.listarReservas()
        }
        return respostaDeErro(404, "Rota nao encontrada")
    }

    private func lerRequisicao(_ fd: Int32) -> (metodo: String, caminho: String, corpo: Data)? {
        var bruto = Data()
        var bloco = [UInt8](repeating: 0, count: 8192)
        while bruto.count < 1_000_000 {
            let lidos = bloco.withUnsafeMutableBytes { ponteiro in
                recv(fd, ponteiro.baseAddress, ponteiro.count, 0)
            }
            if lidos <= 0 {
                break
            }
            bruto.append(contentsOf: bloco.prefix(lidos))
            if let requisicao = interpretar(bruto), requisicao.completa {
                return (requisicao.metodo, requisicao.caminho, requisicao.corpo)
            }
        }
        return nil
    }

    private func interpretar(_ bruto: Data) -> (metodo: String, caminho: String, corpo: Data, completa: Bool)? {
        let separador = Data("\r\n\r\n".utf8)
        guard let faixa = bruto.range(of: separador) else { return nil }
        let cabecalho = bruto.subdata(in: bruto.startIndex..<faixa.lowerBound)
        guard let texto = String(data: cabecalho, encoding: .utf8) else { return nil }
        let linhas = texto.components(separatedBy: "\r\n")
        guard let primeira = linhas.first else { return nil }
        let partes = primeira.split(separator: " ")
        guard partes.count >= 2 else { return nil }
        let metodo = String(partes[0])
        let caminhoCompleto = String(partes[1])
        let caminho = caminhoCompleto.split(separator: "?").first.map(String.init) ?? caminhoCompleto
        var tamanho = 0
        for linha in linhas.dropFirst() {
            if linha.lowercased().hasPrefix("content-length:") {
                let valor = linha.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                tamanho = Int(valor) ?? 0
            }
        }
        let corpoBruto = bruto.subdata(in: faixa.upperBound..<bruto.endIndex)
        let completa = corpoBruto.count >= tamanho
        let corpo = completa ? corpoBruto.prefix(tamanho) : corpoBruto
        return (metodo, caminho, Data(corpo), completa)
    }

    private func escrever(_ fd: Int32, _ resposta: Resposta) {
        let payload = Data(resposta.corpo.utf8)
        let cabecalho = "HTTP/1.1 \(resposta.status) \(frase(resposta.status))\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        var dados = Data(cabecalho.utf8)
        dados.append(payload)
        dados.withUnsafeBytes { ponteiro in
            guard let base = ponteiro.baseAddress else { return }
            var enviados = 0
            while enviados < dados.count {
                let n = send(fd, base.advanced(by: enviados), dados.count - enviados, 0)
                if n <= 0 {
                    break
                }
                enviados += n
            }
        }
    }

    private func frase(_ status: Int) -> String {
        switch status {
        case 200:
            return "OK"
        case 201:
            return "Created"
        case 400:
            return "Bad Request"
        case 403:
            return "Forbidden"
        case 404:
            return "Not Found"
        case 409:
            return "Conflict"
        default:
            return "Error"
        }
    }
}
