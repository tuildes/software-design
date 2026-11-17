import Foundation

protocol EspacoEsportivoRepository: AnyObject {
    func salvar(_ espaco: EspacoEsportivo)
    func buscarPorId(_ id: UUID) -> EspacoEsportivo?
    func listarTodos() -> [EspacoEsportivo]
}
