import Foundation
import Network

class HTTPServer {
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    var onCommand: ((URL) -> Void)?

    func start(port: UInt16) throws {
        stop()
        let nwPort = NWEndpoint.Port(rawValue: port)!
        listener = try NWListener(using: .tcp, on: nwPort)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("HTTPServer failed: \(error)")
            }
        }

        listener?.start(queue: .main)
        self.port = port
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = 0
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let data = data, error == nil else {
                connection.cancel()
                return
            }
            self?.processRequest(data: data, connection: connection)
        }
    }

    private func processRequest(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8),
              let requestLine = request.components(separatedBy: "\r\n").first else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }

        let method = parts[0]
        let path = parts[1]

        guard method == "GET" || method == "POST" else {
            sendResponse(connection: connection, status: 405, body: "{\"error\":\"method not allowed\"}")
            return
        }

        // Handle /help endpoint
        if path == "/help" || path == "/help/" {
            let help: [[String: String]] = [
                ["command": "/set-color", "params": "hex=RRGGBB or r=0.0&g=0.0&b=1.0", "description": "Set lava color"],
                ["command": "/random-color", "params": "", "description": "Set a random harmonious color"],
                ["command": "/set-speed", "params": "value=0.5", "description": "Set animation speed"],
                ["command": "/play", "params": "", "description": "Resume animation"],
                ["command": "/stop", "params": "", "description": "Pause animation"],
                ["command": "/toggle", "params": "", "description": "Toggle animation play/pause"],
                ["command": "/set-title", "params": "text=Hello", "description": "Set title below the lamp"],
                ["command": "/set-title-font", "params": "name=Menlo", "description": "Set title font"],
                ["command": "/set-title-font-size", "params": "value=14", "description": "Set title font size"],
                ["command": "/http", "params": "port=8080 or action=stop", "description": "Start/stop HTTP server"],
                ["command": "/quit", "params": "", "description": "Quit the app"],
                ["command": "/help", "params": "", "description": "Show this help"]
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: ["commands": help], options: .prettyPrinted),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                sendResponse(connection: connection, status: 200, body: jsonStr)
            }
            return
        }

        // Map HTTP path to lavalamp:// URL
        // e.g. /set-color?hex=FF6600 -> lavalamp://set-color?hex=FF6600
        guard let url = URL(string: "lavalamp:/\(path)") else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid path\"}")
            return
        }

        let command = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        DispatchQueue.main.async { [weak self] in
            if let urlForCommand = URL(string: "lavalamp://\(command)?\(url.query ?? "")") {
                self?.onCommand?(urlForCommand)
            } else if let urlForCommand = URL(string: "lavalamp://\(command)") {
                self?.onCommand?(urlForCommand)
            }
            self?.sendResponse(connection: connection, status: 200, body: "{\"ok\":true,\"command\":\"\(command)\"}")
        }
    }

    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Error"
        }

        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        let responseData = response.data(using: .utf8)!
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
