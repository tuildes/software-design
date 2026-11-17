import Foundation

final class SqliteUsuarioRepository: UsuarioRepository {
    private let banco: BancoSqlite

    init(banco: BancoSqlite) {
        self.banco = banco
    }

    func salvar(_ usuario: Usuario) {
        banco.executar(
            """
            INSERT INTO usuarios (id, nome, email, telefone, perfil, ativo)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                nome = excluded.nome,
                email = excluded.email,
                telefone = excluded.telefone,
                perfil = excluded.perfil,
                ativo = excluded.ativo
            """,
            [
                usuario.id.uuidString,
                usuario.nome,
                usuario.email,
                usuario.telefone,
                usuario.perfil.rawValue,
                usuario.ativo ? "1" : "0",
            ]
        )
    }

    func buscarPorId(_ id: UUID) -> Usuario? {
        let linhas = banco.consultar(
            "SELECT id, nome, email, telefone, perfil, ativo FROM usuarios WHERE id = ?",
            [id.uuidString]
        )
        guard let linha = linhas.first else { return nil }
        return montar(linha)
    }

    private func montar(_ linha: [String: String]) -> Usuario? {
        guard let id = UUID(uuidString: linha["id"] ?? ""),
              let perfil = TipoPerfil(rawValue: linha["perfil"] ?? "") else {
            print("Erro de persistencia: usuario invalido")
            return nil
        }
        return Usuario(
            id: id,
            nome: linha["nome"] ?? "",
            email: linha["email"] ?? "",
            telefone: linha["telefone"] ?? "",
            perfil: perfil,
            ativo: (linha["ativo"] ?? "0") == "1"
        )
    }
}
