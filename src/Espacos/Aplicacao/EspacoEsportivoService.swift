import Foundation

final class EspacoEsportivoService: EspacoPort {
    private let espacoRepository: EspacoEsportivoRepository
    private let usuarioRepository: UsuarioRepository

    init(espacoRepository: EspacoEsportivoRepository, usuarioRepository: UsuarioRepository) {
        self.espacoRepository = espacoRepository
        self.usuarioRepository = usuarioRepository
    }

    func cadastrarEspaco(usuarioId: UUID, nome: String, tipo: String, capacidade: Int) throws -> EspacoEsportivo {
        guard let usuario = usuarioRepository.buscarPorId(usuarioId) else {
            throw ErroDeEspaco.usuarioNaoEncontrado
        }
        if usuario.perfil != .admin || !usuario.ativo {
            throw ErroDeEspaco.naoAutorizado
        }
        let espaco = EspacoEsportivo(nome: nome, tipo: tipo, capacidade: capacidade)
        espacoRepository.salvar(espaco)
        return espaco
    }

    func agendarManutencao(espacoId: UUID, periodo: PeriodoHorario) throws {
        guard let espaco = espacoRepository.buscarPorId(espacoId) else {
            throw ErroDeEspaco.naoEncontrado
        }
        if !periodo.ehValido() {
            throw ErroDeEspaco.periodoInvalido
        }
        espaco.iniciarManutencao(periodo)
        espacoRepository.salvar(espaco)
    }

    func liberarManutencao(espacoId: UUID) throws {
        guard let espaco = espacoRepository.buscarPorId(espacoId) else {
            throw ErroDeEspaco.naoEncontrado
        }
        espaco.encerrarManutencao()
        espacoRepository.salvar(espaco)
    }

    func definirRestricoes(espacoId: UUID, restricoes: [RestricaoDeUso]) throws {
        guard let espaco = espacoRepository.buscarPorId(espacoId) else {
            throw ErroDeEspaco.naoEncontrado
        }
        espaco.definirRestricoes(restricoes)
        espacoRepository.salvar(espaco)
    }
}
