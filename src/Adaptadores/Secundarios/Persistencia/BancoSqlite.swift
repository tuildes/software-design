import Foundation
import SQLite3

final class BancoSqlite {
    private var db: OpaquePointer?
    private let transiente = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(caminho: String) throws {
        var ponteiro: OpaquePointer?
        if sqlite3_open(caminho, &ponteiro) != SQLITE_OK {
            let mensagem: String
            if let ponteiro {
                mensagem = String(cString: sqlite3_errmsg(ponteiro))
                sqlite3_close(ponteiro)
            } else {
                mensagem = "nao foi possivel abrir o banco"
            }
            throw ErroExterno(description: mensagem)
        }
        db = ponteiro
        sqlite3_busy_timeout(ponteiro, 3000)
        guard executar("PRAGMA foreign_keys = ON") else {
            throw ErroExterno(description: "nao foi possivel habilitar chaves estrangeiras")
        }
        guard criarTabelas() else {
            throw ErroExterno(description: "nao foi possivel criar o esquema")
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func transacao<T>(_ bloco: () throws -> T) rethrows -> T {
        _ = executar("BEGIN")
        do {
            let resultado = try bloco()
            _ = executar("COMMIT")
            return resultado
        } catch {
            _ = executar("ROLLBACK")
            throw error
        }
    }

    @discardableResult
    func executar(_ sql: String, _ valores: [String] = []) -> Bool {
        guard let db else {
            print("Erro de persistencia: banco fechado")
            return false
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("Erro de persistencia: \(String(cString: sqlite3_errmsg(db))) sql=\(sql)")
            return false
        }
        defer { sqlite3_finalize(stmt) }
        ligar(stmt, valores)
        let passo = sqlite3_step(stmt)
        if passo != SQLITE_DONE && passo != SQLITE_ROW {
            print("Erro de persistencia: \(String(cString: sqlite3_errmsg(db))) sql=\(sql)")
            return false
        }
        return true
    }

    func consultar(_ sql: String, _ valores: [String] = []) -> [[String: String]] {
        guard let db else {
            print("Erro de persistencia: banco fechado")
            return []
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("Erro de persistencia: \(String(cString: sqlite3_errmsg(db))) sql=\(sql)")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        ligar(stmt, valores)
        var linhas: [[String: String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var linha: [String: String] = [:]
            let colunas = sqlite3_column_count(stmt)
            var indice: Int32 = 0
            while indice < colunas {
                if let nomePtr = sqlite3_column_name(stmt, indice) {
                    let nome = String(cString: nomePtr)
                    if let textoPtr = sqlite3_column_text(stmt, indice) {
                        linha[nome] = String(cString: textoPtr)
                    } else {
                        linha[nome] = ""
                    }
                }
                indice += 1
            }
            linhas.append(linha)
        }
        return linhas
    }

    private func ligar(_ stmt: OpaquePointer?, _ valores: [String]) {
        for (indice, valor) in valores.enumerated() {
            _ = valor.withCString { ponteiro in
                sqlite3_bind_text(stmt, Int32(indice + 1), ponteiro, -1, transiente)
            }
        }
    }

    private func criarTabelas() -> Bool {
        let esquema = """
        CREATE TABLE IF NOT EXISTS usuarios (
            id TEXT PRIMARY KEY,
            nome TEXT NOT NULL,
            email TEXT NOT NULL,
            telefone TEXT NOT NULL,
            perfil TEXT NOT NULL,
            ativo TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS espacos (
            id TEXT PRIMARY KEY,
            nome TEXT NOT NULL,
            tipo TEXT NOT NULL,
            capacidade TEXT NOT NULL,
            em_manutencao TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS periodos_manutencao (
            espaco_id TEXT NOT NULL,
            data TEXT NOT NULL,
            hora_inicio TEXT NOT NULL,
            hora_fim TEXT NOT NULL,
            FOREIGN KEY (espaco_id) REFERENCES espacos(id)
        );
        CREATE TABLE IF NOT EXISTS restricoes (
            id TEXT PRIMARY KEY,
            espaco_id TEXT NOT NULL,
            descricao TEXT NOT NULL,
            duracao_maxima_minutos TEXT NOT NULL,
            antecedencia_minima_horas TEXT NOT NULL,
            apenas_usuarios_autorizados TEXT NOT NULL,
            FOREIGN KEY (espaco_id) REFERENCES espacos(id)
        );
        CREATE TABLE IF NOT EXISTS reservas (
            id TEXT PRIMARY KEY,
            espaco_id TEXT NOT NULL,
            usuario_id TEXT NOT NULL,
            data TEXT NOT NULL,
            hora_inicio TEXT NOT NULL,
            hora_fim TEXT NOT NULL,
            status TEXT NOT NULL,
            FOREIGN KEY (espaco_id) REFERENCES espacos(id),
            FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
        );
        CREATE INDEX IF NOT EXISTS idx_reservas_espaco_data ON reservas (espaco_id, data);
        """
        guard let db else { return false }
        if sqlite3_exec(db, esquema, nil, nil, nil) != SQLITE_OK {
            print("Erro de persistencia: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        return true
    }
}
