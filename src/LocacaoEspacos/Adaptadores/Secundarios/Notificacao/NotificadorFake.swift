final class NotificadorFake: Notificador {
    private(set) var enviados: [(destinatario: String, assunto: String, mensagem: String)] = []

    func notificar(destinatario: String, assunto: String, mensagem: String) {
        enviados.append((destinatario: destinatario, assunto: assunto, mensagem: mensagem))
        print("[NotificadorFake] conexao simulada aberta")
        print("[NotificadorFake] destinatario=\(destinatario) assunto=\(assunto) mensagem=\(mensagem)")
        print("[NotificadorFake] conexao simulada encerrada")
    }
}
