import Foundation

final class EspacoEsportivoService {
    private let espacoRepository: EspacoEsportivoRepository

    init(espacoRepository: EspacoEsportivoRepository) {
        self.espacoRepository = espacoRepository
    }

    func cadastrarEspaco(nome: String, tipo: String, capacidade: Int) -> EspacoEsportivo {
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
