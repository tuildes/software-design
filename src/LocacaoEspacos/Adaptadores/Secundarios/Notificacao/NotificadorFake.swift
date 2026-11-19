final class NotificadorFake: Notificador {
    private(set) var enviados: [(destinatario: String, assunto: String, mensagem: String)] = []

    func notificar(destinatario: String, assunto: String, mensagem: String) {
        enviados.append((destinatario: destinatario, assunto: assunto, mensagem: mensagem))
        let corte = TerminalCor.magenta(String(repeating: "─", count: 56))
        print("")
        print(corte)
        print("  \(TerminalCor.destaque("NotificadorFake"))  \(TerminalCor.esmaecido("(adaptador secundario)"))")
        print(corte)
        print("  \(TerminalCor.rotulo("Destinatario"))  \(destinatario)")
        print("  \(TerminalCor.rotulo("Assunto"))       \(assunto)")
        print("  \(TerminalCor.rotulo("Mensagem"))      \(mensagem)")
        print(corte)
        print("")
    }
}
