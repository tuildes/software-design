import Foundation

final class InMemoryUsuarioRepository: UsuarioRepository {
    private var itens: [UUID: Usuario] = [:]

    func salvar(_ usuario: Usuario) {
        itens[usuario.id] = usuario
    }

    func buscarPorId(_ id: UUID) -> Usuario? {
        itens[id]
    }
}
