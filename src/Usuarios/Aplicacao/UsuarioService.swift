import Foundation

final class UsuarioService: UsuarioPort {
    private let usuarioRepository: UsuarioRepository

    init(usuarioRepository: UsuarioRepository) {
        self.usuarioRepository = usuarioRepository
    }

    func cadastrarUsuario(nome: String, email: String, telefone: String, perfil: TipoPerfil) -> Usuario {
        let usuario = Usuario(nome: nome, email: email, telefone: telefone, perfil: perfil, ativo: true)
        usuarioRepository.salvar(usuario)
        return usuario
    }

    func buscarUsuario(usuarioId: UUID) -> Usuario? {
        usuarioRepository.buscarPorId(usuarioId)
    }
}
