import Foundation

public enum ModoPersistencia {
    case memoria
    case sqlite(caminho: String)
}

public enum ModoNotificador {
    case email
    case fake
}

public struct ErroDeArranque: Error, CustomStringConvertible {
    public let description: String
}

struct Nucleo {
    let usuarioService: UsuarioService
    let espacoService: EspacoEsportivoService
    let reservaService: ReservaService
    let usuarios: UsuarioRepository
    let espacos: EspacoEsportivoRepository
    let reservas: ReservaRepository
    let notificador: Notificador
}

func montarNucleo(persistencia: ModoPersistencia, notificador: ModoNotificador) throws -> Nucleo {
    let usuarios: UsuarioRepository
    let espacos: EspacoEsportivoRepository
    let reservas: ReservaRepository
    let unidade: UnidadeDeTrabalho

    switch persistencia {
    case .memoria:
        let usuariosMemoria = InMemoryUsuarioRepository()
        let espacosMemoria = InMemoryEspacoEsportivoRepository()
        let reservasMemoria = InMemoryReservaRepository()
        usuarios = usuariosMemoria
        espacos = espacosMemoria
        reservas = reservasMemoria
        unidade = UnidadeDeTrabalhoImediata()
    case .sqlite(let caminho):
        let banco = try BancoSqlite(caminho: caminho)
        let usuariosSqlite = SqliteUsuarioRepository(banco: banco)
        let espacosSqlite = SqliteEspacoEsportivoRepository(banco: banco)
        let reservasSqlite = SqliteReservaRepository(banco: banco, usuarios: usuariosSqlite, espacos: espacosSqlite)
        usuarios = usuariosSqlite
        espacos = espacosSqlite
        reservas = reservasSqlite
        unidade = SqliteUnidadeDeTrabalho(banco: banco)
    }

    let canal: Notificador
    switch notificador {
    case .email:
        canal = EmailNotificador()
    case .fake:
        canal = NotificadorFake()
    }

    let usuarioService = UsuarioService(usuarioRepository: usuarios)
    let espacoService = EspacoEsportivoService(espacoRepository: espacos, usuarioRepository: usuarios)
    let reservaService = ReservaService(
        reservaRepository: reservas,
        espacoRepository: espacos,
        usuarioRepository: usuarios,
        notificador: canal,
        unidadeDeTrabalho: unidade
    )
    return Nucleo(
        usuarioService: usuarioService,
        espacoService: espacoService,
        reservaService: reservaService,
        usuarios: usuarios,
        espacos: espacos,
        reservas: reservas,
        notificador: canal
    )
}

func montarServidor(porta: UInt16, persistencia: ModoPersistencia, notificador: ModoNotificador) throws -> ServidorHttp {
    let nucleo = try montarNucleo(persistencia: persistencia, notificador: notificador)
    return ServidorHttp(
        porta: porta,
        usuarios: UsuarioController(usuarioPort: nucleo.usuarioService),
        espacos: EspacoEsportivoController(espacoPort: nucleo.espacoService),
        reservas: ReservaController(reservaPort: nucleo.reservaService)
    )
}

public func iniciarServidor(porta: UInt16, persistencia: ModoPersistencia, notificador: ModoNotificador) throws {
    let servidor: ServidorHttp
    do {
        servidor = try montarServidor(porta: porta, persistencia: persistencia, notificador: notificador)
    } catch let erro as ErroExterno {
        throw ErroDeArranque(description: erro.description)
    }
    anunciar(persistencia: persistencia, notificador: notificador)
    do {
        try servidor.iniciar()
    } catch let erro as ErroExterno {
        throw ErroDeArranque(description: erro.description)
    }
}

private func anunciar(persistencia: ModoPersistencia, notificador: ModoNotificador) {
    let largura = 56
    let linha = TerminalCor.ciano(String(repeating: "=", count: largura))
    let corte = TerminalCor.ciano(String(repeating: "─", count: largura))

    print("")
    print(linha)
    print("  \(TerminalCor.titulo("Locacao de Espacos Esportivos"))")
    print(linha)
    print("")

    switch notificador {
    case .email:
        print("  \(TerminalCor.rotulo("Notificador"))   \(TerminalCor.destaque("EmailNotificador"))")
    case .fake:
        print("  \(TerminalCor.rotulo("Notificador"))   \(TerminalCor.destaque("NotificadorFake"))")
    }
    switch persistencia {
    case .memoria:
        print("  \(TerminalCor.rotulo("Persistencia"))  \(TerminalCor.verde("InMemory")) \(TerminalCor.esmaecido("(repositorios em memoria)"))")
    case .sqlite(let caminho):
        print("  \(TerminalCor.rotulo("Persistencia"))  \(TerminalCor.verde("SQLite"))  \(caminho)")
    }

    print("")
    print(corte)
    print("  \(TerminalCor.rotulo("Arquitetura"))   Monolito modular + Hexagonal + Repository")
    print("  \(TerminalCor.rotulo("Modulos"))       Reservas | Espacos | Usuarios | Notificacao")
    print("  \(TerminalCor.rotulo("Adaptadores"))   trocaveis via flags da CLI")
    print(corte)
    print("")
}
