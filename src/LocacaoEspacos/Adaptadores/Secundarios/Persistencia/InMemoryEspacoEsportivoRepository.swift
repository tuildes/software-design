import Foundation

final class InMemoryEspacoEsportivoRepository: EspacoEsportivoRepository {
    private var itens: [UUID: EspacoEsportivo] = [:]

    func salvar(_ espaco: EspacoEsportivo) {
        itens[espaco.id] = espaco
    }

    func buscarPorId(_ id: UUID) -> EspacoEsportivo? {
        itens[id]
    }

    func listarTodos() -> [EspacoEsportivo] {
        Array(itens.values)
    }
}
