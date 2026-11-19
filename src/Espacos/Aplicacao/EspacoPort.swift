import Foundation

protocol EspacoPort: AnyObject {
    func cadastrarEspaco(usuarioId: UUID, nome: String, tipo: String, capacidade: Int) throws -> EspacoEsportivo
    func agendarManutencao(espacoId: UUID, periodo: PeriodoHorario) throws
    func liberarManutencao(espacoId: UUID) throws
    func definirRestricoes(espacoId: UUID, restricoes: [RestricaoDeUso]) throws
}
