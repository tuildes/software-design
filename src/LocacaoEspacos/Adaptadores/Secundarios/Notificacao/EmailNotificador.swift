final class EmailNotificador: Notificador {
    private(set) var enviados: [(destinatario: String, assunto: String, mensagem: String)] = []

    func notificar(destinatario: String, assunto: String, mensagem: String) {
        enviados.append((destinatario: destinatario, assunto: assunto, mensagem: mensagem))
        print("[EmailNotificador] conexao SMTP simulada aberta")
        print("[EmailNotificador] destinatario=\(destinatario) assunto=\(assunto) mensagem=\(mensagem)")
        print("[EmailNotificador] conexao SMTP simulada encerrada")
    }
}
