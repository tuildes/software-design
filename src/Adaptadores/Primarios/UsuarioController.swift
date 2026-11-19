import Foundation

final class UsuarioController {
    private let usuarioPort: UsuarioPort

    init(usuarioPort: UsuarioPort) {
        self.usuarioPort = usuarioPort
    }

    func cadastrarUsuario(corpo: Data) -> Resposta {
        guard let objeto = objetoJson(corpo),
              let nome = textoJson(objeto["nome"]), !nome.isEmpty,
              let email = textoJson(objeto["email"]), !email.isEmpty,
              let telefone = textoJson(objeto["telefone"]), !telefone.isEmpty else {
            return respostaDeErro(400, "Requisicao invalida")
        }
        let perfil: TipoPerfil
        if let bruto = textoJson(objeto["perfil"]) {
            guard let valor = TipoPerfil(rawValue: bruto.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) else {
                return respostaDeErro(400, "Requisicao invalida: perfil (use CLIENTE ou ADMIN)")
            }
            perfil = valor
        } else {
            perfil = .cliente
        }
        let usuario = usuarioPort.cadastrarUsuario(nome: nome, email: email, telefone: telefone, perfil: perfil)
        return Resposta(
            status: 201,
            corpo: json([
                "id": usuario.id.uuidString,
                "nome": usuario.nome,
                "email": usuario.email,
                "telefone": usuario.telefone,
                "perfil": usuario.perfil.rawValue,
                "ativo": usuario.ativo,
            ])
        )
    }
}
