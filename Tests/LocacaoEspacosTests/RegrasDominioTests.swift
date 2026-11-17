import XCTest
@testable import LocacaoEspacos

final class RegrasDominioTests: XCTestCase {
    func testSobreposicaoDePeriodo() {
        let base = periodo("2026-11-20", "19:00", "20:00")
        XCTAssertTrue(base.sobrepoe(periodo("2026-11-20", "19:00", "20:00")))
        XCTAssertTrue(base.sobrepoe(periodo("2026-11-20", "19:30", "20:30")))
        XCTAssertTrue(periodo("2026-11-20", "18:00", "21:00").sobrepoe(base))
        XCTAssertFalse(base.sobrepoe(periodo("2026-11-20", "20:00", "21:00")))
        XCTAssertFalse(base.sobrepoe(periodo("2026-11-21", "19:00", "20:00")))
        XCTAssertTrue(base.ehValido())
        XCTAssertFalse(periodo("2026-11-20", "20:00", "19:00").ehValido())
        XCTAssertFalse(periodo("2026-11-20", "19:00", "19:00").ehValido())
    }

    func testConflitoSoComReservaAtiva() {
        let usuario = usuarioCliente()
        let espaco = EspacoEsportivo(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 10)
        let horario = periodo("2026-11-20", "19:00", "20:00")
        let reserva = Reserva(espacoEsportivo: espaco, usuario: usuario, periodoHorario: horario)
        XCTAssertTrue(reserva.estaAtiva())
        XCTAssertTrue(reserva.conflitaCom(horario))
        XCTAssertTrue(reserva.conflitaCom(periodo("2026-11-20", "19:15", "19:45")))
        XCTAssertFalse(reserva.conflitaCom(periodo("2026-11-20", "20:00", "21:00")))
        reserva.cancelar()
        XCTAssertFalse(reserva.estaAtiva())
        XCTAssertEqual(reserva.status, .cancelada)
        XCTAssertFalse(reserva.conflitaCom(horario))
    }

    func testAptidaoDoUsuario() {
        XCTAssertTrue(usuarioCliente().podeRealizarReserva())
        XCTAssertFalse(usuarioCliente(ativo: false).podeRealizarReserva())
        XCTAssertFalse(usuarioCliente(perfil: .admin).podeRealizarReserva())
    }

    func testManutencaoBloqueiaSomentePeriodoSobreposto() {
        let espaco = EspacoEsportivo(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 10)
        let manutencao = periodo("2026-11-20", "19:00", "20:00")
        espaco.iniciarManutencao(manutencao)
        XCTAssertTrue(espaco.emManutencao)
        XCTAssertFalse(espaco.estaDisponivelParaReserva(manutencao))
        XCTAssertTrue(espaco.estaDisponivelParaReserva(periodo("2026-11-20", "21:00", "22:00")))
        espaco.encerrarManutencao()
        XCTAssertFalse(espaco.emManutencao)
        XCTAssertTrue(espaco.periodosManutencao.isEmpty)
        XCTAssertTrue(espaco.estaDisponivelParaReserva(manutencao))
    }

    func testManutencaoSemJanelaBloqueiaQualquerHorario() {
        let espaco = EspacoEsportivo(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 10, emManutencao: true)
        XCTAssertFalse(espaco.estaDisponivelParaReserva(periodo("2026-11-20", "19:00", "20:00")))
    }

    func testRestricaoDeDuracaoEAntecedencia() {
        let usuario = usuarioCliente()
        let curta = RestricaoDeUso(
            descricao: "maximo 30 minutos",
            duracaoMaximaMinutos: 30,
            antecedenciaMinimaHoras: 0,
            apenasUsuariosAutorizados: false
        )
        XCTAssertFalse(curta.validar(usuario, periodo("2026-12-01", "19:00", "20:00")))
        XCTAssertTrue(curta.validar(usuario, periodo("2026-12-01", "19:00", "19:30")))

        let antecedencia = RestricaoDeUso(
            descricao: "com antecedencia",
            duracaoMaximaMinutos: 0,
            antecedenciaMinimaHoras: 1,
            apenasUsuariosAutorizados: false
        )
        XCTAssertFalse(antecedencia.validar(usuario, periodo("2020-01-01", "19:00", "20:00")))
        XCTAssertTrue(antecedencia.validar(usuario, periodo("2030-01-01", "19:00", "20:00")))

        let soAutorizados = RestricaoDeUso(
            descricao: "autorizados",
            duracaoMaximaMinutos: 0,
            antecedenciaMinimaHoras: 0,
            apenasUsuariosAutorizados: true
        )
        XCTAssertFalse(soAutorizados.validar(usuarioCliente(ativo: false), periodo("2030-01-01", "19:00", "20:00")))
        XCTAssertTrue(soAutorizados.validar(usuario, periodo("2030-01-01", "19:00", "20:00")))
    }

    func testEspacoExigeTodasAsRestricoes() {
        let espaco = EspacoEsportivo(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 10)
        let usuario = usuarioCliente()
        espaco.adicionarRestricao(
            RestricaoDeUso(
                descricao: "maximo 30",
                duracaoMaximaMinutos: 30,
                antecedenciaMinimaHoras: 0,
                apenasUsuariosAutorizados: false
            )
        )
        XCTAssertFalse(espaco.atendeRestricoes(usuario, periodo("2026-12-01", "19:00", "20:00")))
        XCTAssertTrue(espaco.atendeRestricoes(usuario, periodo("2026-12-01", "19:00", "19:20")))
        espaco.definirRestricoes([])
        XCTAssertTrue(espaco.atendeRestricoes(usuario, periodo("2026-12-01", "19:00", "20:00")))
    }
}
