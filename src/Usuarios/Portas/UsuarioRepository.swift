import Foundation

protocol UsuarioRepository: AnyObject {
    func salvar(_ usuario: Usuario)
    func buscarPorId(_ id: UUID) -> Usuario?
}
