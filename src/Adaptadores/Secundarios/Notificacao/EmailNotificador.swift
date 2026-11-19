final class EmailNotificador: Notificador {
    private(set) var enviados: [(destinatario: String, assunto: String, mensagem: String)] = []

    func notificar(destinatario: String, assunto: String, mensagem: String) {
        enviados.append((destinatario: destinatario, assunto: assunto, mensagem: mensagem))
        let corte = TerminalCor.magenta(String(repeating: "─", count: 56))
        print("")
        print(corte)
        print("  \(TerminalCor.destaque("EmailNotificador"))  \(TerminalCor.esmaecido("(SMTP simulado)"))")
        print(corte)
        print("  \(TerminalCor.rotulo("Destinatario"))  \(destinatario)")
        print("  \(TerminalCor.rotulo("Assunto"))       \(assunto)")
        print("  \(TerminalCor.rotulo("Mensagem"))      \(mensagem)")
        print(corte)
        print("")
    }
}
