import Foundation

/// Porta primária do módulo Espacos (entrada do hexágono).
protocol EspacoPort: AnyObject {
    func cadastrarEspaco(nome: String, tipo: String, capacidade: Int) -> EspacoEsportivo
    func agendarManutencao(espacoId: UUID, periodo: PeriodoHorario) throws
    func liberarManutencao(espacoId: UUID) throws
    func definirRestricoes(espacoId: UUID, restricoes: [RestricaoDeUso]) throws
}
