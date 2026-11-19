import Foundation

/// Porta primária do módulo Usuarios (entrada do hexágono).
protocol UsuarioPort: AnyObject {
    func cadastrarUsuario(nome: String, email: String, telefone: String, perfil: TipoPerfil) -> Usuario
    func buscarUsuario(usuarioId: UUID) -> Usuario?
}
