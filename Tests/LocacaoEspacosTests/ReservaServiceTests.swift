import XCTest
@testable import LocacaoEspacos

final class ReservaServiceTests: XCTestCase {
    func testFluxoFelizComNotificadorFakeEmMemoria() throws {
        try assertFluxoFeliz(persistencia: .memoria, notificador: .fake)
    }

    func testFluxoFelizComEmailNotificadorEmMemoria() throws {
        try assertFluxoFeliz(persistencia: .memoria, notificador: .email)
    }

    func testFluxoFelizComNotificadorFakeEmSqlite() throws {
        let caminho = arquivoTemporario()
        defer { try? FileManager.default.removeItem(atPath: caminho) }
        try assertFluxoFeliz(persistencia: .sqlite(caminho: caminho), notificador: .fake)
    }

    func testTrocaDeAdaptadorMantemOProtocolo() throws {
        let email = try montarNucleo(persistencia: .memoria, notificador: .email)
        let fake = try montarNucleo(persistencia: .memoria, notificador: .fake)
        XCTAssertTrue(email.notificador is EmailNotificador)
        XCTAssertTrue(fake.notificador is NotificadorFake)
    }

    func testUsuarioInaptoNaoReservaNemNotifica() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let (admin, espaco) = preparar(nucleo, perfil: .admin)
        let horario = periodo("2026-12-01", "19:00", "20:00")
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: admin.id, espacoId: espaco.id, periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .usuarioNaoAutorizado)
            XCTAssertEqual((erro as? ErroDeReserva)?.mensagem, "Usuario nao autorizado a reservar")
        }
        let inativo = usuarioCliente(email: "inativo@exemplo.com", ativo: false)
        nucleo.usuarios.salvar(inativo)
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: inativo.id, espacoId: espaco.id, periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .usuarioNaoAutorizado)
        }
        XCTAssertTrue(try notificadorFake(nucleo).enviados.isEmpty)
        XCTAssertTrue(nucleo.reservas.listarPorEspacoEData(espaco.id, horario.data).isEmpty)
    }

    func testUsuarioOuEspacoInexistente() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let horario = periodo("2026-12-01", "19:00", "20:00")
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: UUID(), espacoId: UUID(), periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .usuarioNaoEncontrado)
        }
        let (usuario, _) = preparar(nucleo)
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: UUID(), periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .espacoNaoEncontrado)
        }
    }

    func testManutencaoERestricaoBloqueiamReserva() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let usuario = nucleo.usuarioService.cadastrarUsuario(nome: "Ana", email: "ana@exemplo.com", telefone: "1", perfil: .cliente)
        let espaco = nucleo.espacoService.cadastrarEspaco(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 10)
        let horario = periodo("2026-12-01", "19:00", "20:00")
        try nucleo.espacoService.agendarManutencao(espacoId: espaco.id, periodo: horario)
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .espacoIndisponivelOuRestricaoViolada)
            XCTAssertEqual((erro as? ErroDeReserva)?.mensagem, "Espaco indisponivel ou restricao violada")
        }
        XCTAssertNoThrow(try nucleo.reservaService.realizarReserva(
            usuarioId: usuario.id,
            espacoId: espaco.id,
            periodo: periodo("2026-12-01", "21:00", "22:00")
        ))
        try nucleo.espacoService.liberarManutencao(espacoId: espaco.id)
        try nucleo.espacoService.definirRestricoes(
            espacoId: espaco.id,
            restricoes: [
                RestricaoDeUso(
                    descricao: "maximo 30",
                    duracaoMaximaMinutos: 30,
                    antecedenciaMinimaHoras: 0,
                    apenasUsuariosAutorizados: false
                ),
            ]
        )
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .espacoIndisponivelOuRestricaoViolada)
        }
        try nucleo.espacoService.definirRestricoes(espacoId: espaco.id, restricoes: [])
        let criada = try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)
        XCTAssertEqual(criada.status, .confirmada)
    }

    func testConflitoEReservaCanceladaNaoOcupaHorario() throws {
        try assertConflito(persistencia: .memoria)
        let caminho = arquivoTemporario()
        defer { try? FileManager.default.removeItem(atPath: caminho) }
        try assertConflito(persistencia: .sqlite(caminho: caminho))
    }

    private func assertConflito(persistencia: ModoPersistencia) throws {
        let nucleo = try montarNucleo(persistencia: persistencia, notificador: .fake)
        let (usuario, espaco) = preparar(nucleo)
        let horario = periodo("2026-12-01", "19:00", "20:00")
        let primeira = try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .horarioJaReservado)
            XCTAssertEqual((erro as? ErroDeReserva)?.mensagem, "Reserva invalida: horario ja reservado")
        }
        XCTAssertEqual(try notificadorFake(nucleo).enviados.count, 1)
        primeira.cancelar()
        nucleo.reservas.salvar(primeira)
        let segunda = try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)
        XCTAssertEqual(segunda.status, .confirmada)
        XCTAssertEqual(nucleo.reservas.listarAtivasPorPeriodo(horario).count, 1)
        XCTAssertEqual(try notificadorFake(nucleo).enviados.count, 2)
    }

    func testPeriodoInvalidoEEspacosDistintos() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        let (usuario, espaco) = preparar(nucleo)
        XCTAssertThrowsError(try nucleo.reservaService.realizarReserva(
            usuarioId: usuario.id,
            espacoId: espaco.id,
            periodo: periodo("2026-12-01", "20:00", "19:00")
        )) { erro in
            XCTAssertEqual(erro as? ErroDeReserva, .periodoInvalido)
        }
        let outro = EspacoEsportivo(nome: "Quadra 2", tipo: "society", capacidade: 12)
        nucleo.espacos.salvar(outro)
        let horario = periodo("2026-12-01", "19:00", "20:00")
        _ = try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)
        let noOutro = try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: outro.id, periodo: horario)
        XCTAssertEqual(noOutro.espacoEsportivo.id, outro.id)
    }

    func testEspacoInexistenteNaManutencao() throws {
        let nucleo = try montarNucleo(persistencia: .memoria, notificador: .fake)
        XCTAssertThrowsError(try nucleo.espacoService.agendarManutencao(espacoId: UUID(), periodo: periodo("2026-12-01", "19:00", "20:00"))) { erro in
            XCTAssertEqual(erro as? ErroDeEspaco, .naoEncontrado)
        }
    }
}

private func assertFluxoFeliz(persistencia: ModoPersistencia, notificador: ModoNotificador) throws {
    let nucleo = try montarNucleo(persistencia: persistencia, notificador: notificador)
    let (usuario, espaco) = preparar(nucleo)
    let horario = periodo("2026-12-01", "19:00", "20:00")
    let reserva = try nucleo.reservaService.realizarReserva(usuarioId: usuario.id, espacoId: espaco.id, periodo: horario)
    XCTAssertEqual(reserva.status, .confirmada)
    XCTAssertEqual(reserva.usuario.email, usuario.email)
    XCTAssertEqual(reserva.espacoEsportivo.id, espaco.id)
    let salva = try XCTUnwrap(nucleo.reservas.buscarPorId(reserva.id))
    XCTAssertEqual(salva.status, .confirmada)
    XCTAssertEqual(salva.periodoHorario, horario)
    XCTAssertEqual(nucleo.reservas.listarPorEspacoEData(espaco.id, horario.data).count, 1)
    switch notificador {
    case .fake:
        let fake = try notificadorFake(nucleo)
        XCTAssertEqual(fake.enviados.count, 1)
        XCTAssertEqual(fake.enviados[0].destinatario, usuario.email)
        XCTAssertEqual(fake.enviados[0].assunto, "Reserva Confirmada")
        XCTAssertTrue(fake.enviados[0].mensagem.contains(espaco.nome))
    case .email:
        let email = try XCTUnwrap(nucleo.notificador as? EmailNotificador)
        XCTAssertEqual(email.enviados.count, 1)
        XCTAssertEqual(email.enviados[0].destinatario, usuario.email)
        XCTAssertEqual(email.enviados[0].assunto, "Reserva Confirmada")
    }
}