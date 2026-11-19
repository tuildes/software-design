import Foundation
import XCTest
@testable import LocacaoEspacos

final class ServidorHttpTests: XCTestCase {
    func testFluxoHttpDeRealizarReserva() throws {
        let porta = UInt16.random(in: 20000...45000)
        let servidor = try montarServidor(porta: porta, persistencia: .memoria, notificador: .fake)
        let thread = Thread {
            try? servidor.iniciar()
        }
        thread.start()
        defer {
            servidor.parar()
            let limite = Date().addingTimeInterval(2)
            while thread.isExecuting && Date() < limite {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        let base = "http://127.0.0.1:\(porta)"
        let (statusRota, _) = try requisicaoQuandoPronto(metodo: "GET", url: base + "/api/v1/outra", campos: nil)
        XCTAssertEqual(statusRota, 404)

        let (statusUsuario, usuario) = try post(base + "/api/v1/usuarios", [
            "nome": "Ana",
            "email": "ana@exemplo.com",
            "telefone": "11999999999",
        ])
        XCTAssertEqual(statusUsuario, 201)
        let usuarioId = try XCTUnwrap(usuario["id"] as? String)

        let (statusAdmin, admin) = try post(base + "/api/v1/usuarios", [
            "nome": "Admin",
            "email": "admin@exemplo.com",
            "telefone": "1",
            "perfil": "admin",
        ])
        XCTAssertEqual(statusAdmin, 201)
        let adminId = try XCTUnwrap(admin["id"] as? String)

        let (statusClienteEspaco, _) = try post(base + "/api/v1/espacos", [
            "usuarioId": usuarioId,
            "nome": "Quadra Negada",
            "tipo": "poliesportiva",
            "capacidade": 14,
        ])
        XCTAssertEqual(statusClienteEspaco, 403)

        let (statusEspaco, espaco) = try post(base + "/api/v1/espacos", [
            "usuarioId": adminId,
            "nome": "Quadra 1",
            "tipo": "poliesportiva",
            "capacidade": 14,
        ])
        XCTAssertEqual(statusEspaco, 201)
        let espacoId = try XCTUnwrap(espaco["id"] as? String)

        let pedido: [String: Any] = [
            "usuarioId": usuarioId,
            "espacoId": espacoId,
            "data": "2026-12-01",
            "horaInicio": "19:00",
            "horaFim": "20:00",
        ]
        let (statusCriada, criada) = try post(base + "/api/v1/reservas", pedido)
        XCTAssertEqual(statusCriada, 201)
        XCTAssertEqual(criada["status"] as? String, "CONFIRMADA")

        let (statusConflito, conflito) = try post(base + "/api/v1/reservas", pedido)
        XCTAssertEqual(statusConflito, 409)
        XCTAssertEqual(conflito["mensagem"] as? String, "Reserva invalida: horario ja reservado")

        let (statusAdminReserva, adminReserva) = try post(base + "/api/v1/reservas", [
            "usuarioId": adminId,
            "espacoId": espacoId,
            "data": "2026-12-01",
            "horaInicio": "21:00",
            "horaFim": "22:00",
        ])
        XCTAssertEqual(statusAdminReserva, 201)
        XCTAssertEqual(adminReserva["status"] as? String, "CONFIRMADA")
    }
}

private func requisicaoQuandoPronto(metodo: String, url: String, campos: [String: Any]?) throws -> (Int, [String: Any]) {
    var ultimo: Error?
    for _ in 0..<40 {
        do {
            return try requisicao(metodo: metodo, url: url, campos: campos)
        } catch {
            ultimo = error
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
    throw try XCTUnwrap(ultimo)
}

private func post(_ url: String, _ campos: [String: Any]) throws -> (Int, [String: Any]) {
    try requisicao(metodo: "POST", url: url, campos: campos)
}

private func requisicao(metodo: String, url: String, campos: [String: Any]?) throws -> (Int, [String: Any]) {
    var pedido = URLRequest(url: try XCTUnwrap(URL(string: url)))
    pedido.httpMethod = metodo
    pedido.timeoutInterval = 2
    if let campos {
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: campos)
    }
    let fila = OperationQueue()
    let sessao = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: fila)
    let semaforo = DispatchSemaphore(value: 0)
    var dados = Data()
    var status = 0
    var falha: Error?
    sessao.dataTask(with: pedido) { corpo, resposta, erro in
        dados = corpo ?? Data()
        status = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        falha = erro
        semaforo.signal()
    }.resume()
    semaforo.wait()
    sessao.finishTasksAndInvalidate()
    if let falha {
        throw falha
    }
    if dados.isEmpty {
        return (status, [:])
    }
    let json = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] ?? [:]
    return (status, json)
}
