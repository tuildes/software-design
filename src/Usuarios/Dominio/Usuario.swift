import Foundation

final class Usuario {
    let id: UUID
    let nome: String
    let email: String
    let telefone: String
    let perfil: TipoPerfil
    let ativo: Bool

    init(id: UUID = UUID(), nome: String, email: String, telefone: String, perfil: TipoPerfil, ativo: Bool = true) {
        self.id = id
        self.nome = nome
        self.email = email
        self.telefone = telefone
        self.perfil = perfil
        self.ativo = ativo
    }

    func podeRealizarReserva() -> Bool {
        ativo
    }
}
