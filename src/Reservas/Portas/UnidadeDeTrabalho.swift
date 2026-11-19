/// Porta secundária para transação local (Repository Architecture / ACID).
protocol UnidadeDeTrabalho: AnyObject {
    func emTransacao<T>(_ bloco: () throws -> T) rethrows -> T
}

/// No-op para adaptadores em memória / testes.
final class UnidadeDeTrabalhoImediata: UnidadeDeTrabalho {
    func emTransacao<T>(_ bloco: () throws -> T) rethrows -> T {
        try bloco()
    }
}
