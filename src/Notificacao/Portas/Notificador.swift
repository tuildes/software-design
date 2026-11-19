protocol Notificador: AnyObject {
    func notificar(destinatario: String, assunto: String, mensagem: String)
}
