import XCTest
@testable import LocacaoEspacos

final class ControllersTests: XCTestCase {
    func testCadastroEReservaPeloController() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let usuarios = UsuarioController(usuarioService: nucleo.usuarioService)
        let espacos = EspacoEsportivoController(espacoService: nucleo.espacoService)
        let reservas = ReservaController(reservaService: nucleo.reservaService)

        let respostaUsuario = usuarios.cadastrarUsuario(corpo: try corpoJson([
            "nome": "Ana",
            "email": "ana@exemplo.com",
            "telefone": "11999999999",
        ]))
        XCTAssertEqual(respostaUsuario.status, 201)
        let usuario = try objetoDaResposta(respostaUsuario)
        let usuarioId = try XCTUnwrap(usuario["id"] as? String)

        let respostaEspaco = espacos.cadastrarEspaco(corpo: try corpoJson([
            "nome": "Quadra 1",
            "tipo": "poliesportiva",
            "capacidade": 14,
        ]))
        XCTAssertEqual(respostaEspaco.status, 201)
        let espaco = try objetoDaResposta(respostaEspaco)
        let espacoId = try XCTUnwrap(espaco["id"] as? String)

        let pedido = try corpoJson([
            "usuarioId": usuarioId,
            "espacoId": espacoId,
            "data": "2026-12-01",
            "horaInicio": "19:00",
            "horaFim": "20:00",
        ])
        let criada = reservas.criarReserva(corpo: pedido)
        XCTAssertEqual(criada.status, 201)
        let corpo = try objetoDaResposta(criada)
        XCTAssertEqual(corpo["status"] as? String, "CONFIRMADA")
        XCTAssertEqual(corpo["usuarioId"] as? String, usuarioId)
        XCTAssertEqual(corpo["espacoId"] as? String, espacoId)

        let conflito = reservas.criarReserva(corpo: pedido)
        XCTAssertEqual(conflito.status, 409)
        XCTAssertEqual(try objetoDaResposta(conflito)["mensagem"] as? String, "Reserva invalida: horario ja reservado")

        let lista = reservas.listarReservas()
        XCTAssertEqual(lista.status, 200)
        let itens = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(lista.corpo.utf8)) as? [[String: Any]])
        XCTAssertEqual(itens.count, 1)
        XCTAssertEqual(itens[0]["usuarioNome"] as? String, "Ana")
        XCTAssertEqual(itens[0]["espacoNome"] as? String, "Quadra 1")
    }

    func testControllerRecusaFormatoEUsuarioInapto() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let usuarios = UsuarioController(usuarioService: nucleo.usuarioService)
        let reservas = ReservaController(reservaService: nucleo.reservaService)
        XCTAssertEqual(usuarios.cadastrarUsuario(corpo: Data("{}".utf8)).status, 400)
        XCTAssertEqual(reservas.criarReserva(corpo: Data("nao-json".utf8)).status, 400)

        let admin = usuarios.cadastrarUsuario(corpo: try corpoJson([
            "nome": "Admin",
            "email": "admin@exemplo.com",
            "telefone": "1",
            "perfil": "ADMIN",
        ]))
        let espaco = EspacoEsportivoController(espacoService: nucleo.espacoService).cadastrarEspaco(corpo: try corpoJson([
            "nome": "Quadra 1",
            "tipo": "society",
            "capacidade": 10,
        ]))
        let resposta = reservas.criarReserva(corpo: try corpoJson([
            "usuarioId": try XCTUnwrap(try objetoDaResposta(admin)["id"] as? String),
            "espacoId": try XCTUnwrap(try objetoDaResposta(espaco)["id"] as? String),
            "data": "2026-12-01",
            "horaInicio": "19:00",
            "horaFim": "20:00",
        ]))
        XCTAssertEqual(resposta.status, 403)
        XCTAssertEqual(try objetoDaResposta(resposta)["mensagem"] as? String, "Usuario nao autorizado a reservar")
    }

    func testControllerMapeiaManutencaoPara409() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let usuario = nucleo.usuarioService.cadastrarUsuario(nome: "Ana", email: "ana@exemplo.com", telefone: "1", perfil: .cliente)
        let espaco = nucleo.espacoService.cadastrarEspaco(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 10)
        try nucleo.espacoService.agendarManutencao(espacoId: espaco.id, periodo: periodo("2026-12-01", "19:00", "20:00"))
        let reservas = ReservaController(reservaService: nucleo.reservaService)
        let resposta = reservas.criarReserva(corpo: try corpoJson([
            "usuarioId": usuario.id.uuidString,
            "espacoId": espaco.id.uuidString,
            "data": "2026-12-01",
            "horaInicio": "19:00",
            "horaFim": "20:00",
        ]))
        XCTAssertEqual(resposta.status, 409)
        XCTAssertEqual(try objetoDaResposta(resposta)["mensagem"] as? String, "Espaco indisponivel ou restricao violada")
    }
}
