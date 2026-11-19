final class SqliteUnidadeDeTrabalho: UnidadeDeTrabalho {
    private let banco: BancoSqlite

    init(banco: BancoSqlite) {
        self.banco = banco
    }

    func emTransacao<T>(_ bloco: () throws -> T) rethrows -> T {
        try banco.transacao(bloco)
    }
}
