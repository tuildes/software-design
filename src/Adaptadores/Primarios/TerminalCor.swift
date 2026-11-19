import Foundation

/// Cores ANSI para demonstração no terminal.
/// Desliga automaticamente se a saída não for TTY ou se `NO_COLOR` estiver definido.
public enum TerminalCor {
    public static var ativas: Bool {
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
            return false
        }
        if ProcessInfo.processInfo.environment["TERM"] == "dumb" {
            return false
        }
        return isatty(fileno(stdout)) != 0
    }

    public static func aplicar(_ texto: String, _ codigo: String) -> String {
        guard ativas else { return texto }
        return "\u{001B}[\(codigo)m\(texto)\u{001B}[0m"
    }

    public static func negrito(_ texto: String) -> String { aplicar(texto, "1") }
    public static func esmaecido(_ texto: String) -> String { aplicar(texto, "2") }

    public static func ciano(_ texto: String) -> String { aplicar(texto, "36") }
    public static func azul(_ texto: String) -> String { aplicar(texto, "34") }
    public static func verde(_ texto: String) -> String { aplicar(texto, "32") }
    public static func amarelo(_ texto: String) -> String { aplicar(texto, "33") }
    public static func vermelho(_ texto: String) -> String { aplicar(texto, "31") }
    public static func magenta(_ texto: String) -> String { aplicar(texto, "35") }

    public static func titulo(_ texto: String) -> String { aplicar(texto, "1;36") }
    public static func rotulo(_ texto: String) -> String { aplicar(texto, "1;37") }
    public static func sucesso(_ texto: String) -> String { aplicar(texto, "1;32") }
    public static func erro(_ texto: String) -> String { aplicar(texto, "1;31") }
    public static func aviso(_ texto: String) -> String { aplicar(texto, "1;33") }
    public static func destaque(_ texto: String) -> String { aplicar(texto, "1;35") }

    public static func statusHttp(_ codigo: Int) -> String {
        let texto = "HTTP \(codigo)"
        switch codigo {
        case 200..<300: return sucesso(texto)
        case 400..<500: return aviso(texto)
        case 500...: return erro(texto)
        default: return esmaecido(texto)
        }
    }
}
