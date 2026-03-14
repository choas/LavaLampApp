import Foundation
import Network

class HTTPServer {
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    var onCommand: ((URL) -> Void)?
    var onStatus: (() -> [String: Any])?

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

        // Serve web UI at root
        if path == "/" || path == "/index.html" {
            sendResponse(connection: connection, status: 200, body: Self.webPageHTML, contentType: "text/html")
            return
        }

        // Status endpoint for the web UI
        if path == "/status" || path == "/status/" {
            DispatchQueue.main.async { [weak self] in
                let status = self?.onStatus?() ?? [:]
                if let jsonData = try? JSONSerialization.data(withJSONObject: status, options: []),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    self?.sendResponse(connection: connection, status: 200, body: jsonStr)
                } else {
                    self?.sendResponse(connection: connection, status: 200, body: "{}")
                }
            }
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

    private func sendResponse(connection: NWConnection, status: Int, body: String, contentType: String = "application/json") {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Error"
        }

        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
        let responseData = response.data(using: .utf8)!
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Web UI HTML

    static let webPageHTML: String = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LavaLamp Control</title>
    <style>
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, sans-serif;
        background: #1a1a2e;
        color: #e0e0e0;
        min-height: 100vh;
        display: flex;
        justify-content: center;
        align-items: flex-start;
        padding: 40px 20px;
      }

      .container {
        width: 100%;
        max-width: 480px;
      }

      header {
        text-align: center;
        margin-bottom: 32px;
      }

      header h1 {
        font-size: 28px;
        font-weight: 300;
        letter-spacing: 4px;
        text-transform: uppercase;
        background: linear-gradient(135deg, #ff6b35, #f7c948, #ff6b35);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
      }

      header p {
        margin-top: 6px;
        font-size: 13px;
        color: #666;
        letter-spacing: 1px;
      }

      .card {
        background: #16213e;
        border-radius: 16px;
        padding: 24px;
        margin-bottom: 16px;
        border: 1px solid #1a1a3e;
        transition: border-color 0.3s;
      }

      .card:hover {
        border-color: #2a2a5e;
      }

      .card h2 {
        font-size: 11px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 2px;
        color: #888;
        margin-bottom: 16px;
      }

      .color-section {
        display: flex;
        align-items: center;
        gap: 16px;
      }

      .color-preview {
        width: 64px;
        height: 64px;
        border-radius: 50%;
        border: 3px solid #2a2a5e;
        cursor: pointer;
        transition: transform 0.2s, box-shadow 0.3s;
        flex-shrink: 0;
      }

      .color-preview:hover {
        transform: scale(1.08);
      }

      .color-inputs {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 8px;
      }

      .color-hex-row {
        display: flex;
        gap: 8px;
        align-items: center;
      }

      .color-hex-row input[type="text"] {
        flex: 1;
        background: #0f3460;
        border: 1px solid #1a1a3e;
        border-radius: 8px;
        padding: 8px 12px;
        color: #e0e0e0;
        font-family: "SF Mono", Menlo, monospace;
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s;
      }

      .color-hex-row input[type="text"]:focus {
        border-color: #e94560;
      }

      input[type="color"] {
        -webkit-appearance: none;
        width: 36px;
        height: 36px;
        border: none;
        border-radius: 8px;
        cursor: pointer;
        background: transparent;
      }

      input[type="color"]::-webkit-color-swatch-wrapper { padding: 0; }
      input[type="color"]::-webkit-color-swatch {
        border: 2px solid #2a2a5e;
        border-radius: 8px;
      }

      .presets {
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        margin-top: 4px;
      }

      .preset {
        width: 28px;
        height: 28px;
        border-radius: 50%;
        border: 2px solid transparent;
        cursor: pointer;
        transition: transform 0.15s, border-color 0.2s;
      }

      .preset:hover {
        transform: scale(1.2);
        border-color: #fff4;
      }

      .btn {
        background: #0f3460;
        border: 1px solid #1a1a3e;
        color: #e0e0e0;
        padding: 8px 16px;
        border-radius: 8px;
        cursor: pointer;
        font-size: 13px;
        font-weight: 500;
        transition: background 0.2s, transform 0.1s;
        white-space: nowrap;
      }

      .btn:hover { background: #1a4a8a; }
      .btn:active { transform: scale(0.97); }

      .btn.accent {
        background: #e94560;
        border-color: #e94560;
      }

      .btn.accent:hover { background: #c73e54; }

      .slider-row {
        display: flex;
        align-items: center;
        gap: 12px;
      }

      .slider-row label {
        font-size: 13px;
        color: #aaa;
        min-width: 44px;
      }

      .slider-row input[type="range"] {
        flex: 1;
        -webkit-appearance: none;
        height: 6px;
        border-radius: 3px;
        background: #0f3460;
        outline: none;
      }

      .slider-row input[type="range"]::-webkit-slider-thumb {
        -webkit-appearance: none;
        width: 18px;
        height: 18px;
        border-radius: 50%;
        background: #e94560;
        cursor: pointer;
        transition: transform 0.1s;
      }

      .slider-row input[type="range"]::-webkit-slider-thumb:hover {
        transform: scale(1.2);
      }

      .slider-row .value {
        font-family: "SF Mono", Menlo, monospace;
        font-size: 13px;
        color: #aaa;
        min-width: 36px;
        text-align: right;
      }

      .speed-presets {
        display: flex;
        gap: 8px;
        margin-top: 12px;
      }

      .speed-presets .btn {
        flex: 1;
        text-align: center;
        font-size: 12px;
        padding: 6px 8px;
      }

      .speed-presets .btn.active {
        background: #e94560;
        border-color: #e94560;
      }

      .playback-row {
        display: flex;
        gap: 8px;
      }

      .playback-row .btn {
        flex: 1;
        text-align: center;
        font-size: 18px;
        padding: 10px;
      }

      .input-row {
        display: flex;
        gap: 8px;
        align-items: center;
        margin-bottom: 10px;
      }

      .input-row:last-child { margin-bottom: 0; }

      .input-row label {
        font-size: 13px;
        color: #aaa;
        min-width: 60px;
      }

      .input-row input[type="text"],
      .input-row input[type="number"],
      .input-row select {
        flex: 1;
        background: #0f3460;
        border: 1px solid #1a1a3e;
        border-radius: 8px;
        padding: 8px 12px;
        color: #e0e0e0;
        font-size: 13px;
        outline: none;
        transition: border-color 0.2s;
      }

      .input-row input:focus,
      .input-row select:focus {
        border-color: #e94560;
      }

      .input-row select {
        cursor: pointer;
      }

      .input-row select option {
        background: #0f3460;
      }

      .status-dot {
        display: inline-block;
        width: 8px;
        height: 8px;
        border-radius: 50%;
        margin-right: 6px;
        vertical-align: middle;
      }

      .status-dot.connected { background: #4ade80; }
      .status-dot.disconnected { background: #ef4444; }

      .status-bar {
        text-align: center;
        font-size: 12px;
        color: #666;
        margin-top: 16px;
      }

      @media (max-width: 500px) {
        body { padding: 20px 12px; }
        .color-section { flex-direction: column; align-items: stretch; }
        .color-preview { width: 48px; height: 48px; align-self: center; }
      }
    </style>
    </head>
    <body>
    <div class="container">
      <header>
        <h1>LavaLamp</h1>
        <p>Remote Control</p>
      </header>

      <!-- Playback -->
      <div class="card">
        <h2>Playback</h2>
        <div class="playback-row">
          <button class="btn" onclick="send('/play')" title="Play">&#9654;</button>
          <button class="btn" onclick="send('/stop')" title="Pause">&#9646;&#9646;</button>
          <button class="btn" onclick="send('/toggle')" title="Toggle">&#8644;</button>
          <button class="btn accent" onclick="send('/random-color')" title="Random Color">&#127922;</button>
        </div>
      </div>

      <!-- Color -->
      <div class="card">
        <h2>Color</h2>
        <div class="color-section">
          <div class="color-preview" id="colorPreview" onclick="document.getElementById('colorPicker').click()"></div>
          <div class="color-inputs">
            <div class="color-hex-row">
              <input type="text" id="hexInput" placeholder="#FF6600" maxlength="7"
                     onkeydown="if(event.key==='Enter')applyHex()">
              <input type="color" id="colorPicker" onchange="pickerChanged(this.value)">
              <button class="btn" onclick="applyHex()">Set</button>
            </div>
            <div class="presets">
              <div class="preset" style="background:#FF6600" onclick="setColor('FF6600')"></div>
              <div class="preset" style="background:#E53935" onclick="setColor('E53935')"></div>
              <div class="preset" style="background:#1E88E5" onclick="setColor('1E88E5')"></div>
              <div class="preset" style="background:#43A047" onclick="setColor('43A047')"></div>
              <div class="preset" style="background:#8E24AA" onclick="setColor('8E24AA')"></div>
              <div class="preset" style="background:#F06292" onclick="setColor('F06292')"></div>
              <div class="preset" style="background:#FFB300" onclick="setColor('FFB300')"></div>
              <div class="preset" style="background:#00ACC1" onclick="setColor('00ACC1')"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Speed -->
      <div class="card">
        <h2>Speed</h2>
        <div class="slider-row">
          <label>Speed</label>
          <input type="range" id="speedSlider" min="0.05" max="2.0" step="0.05" value="0.5"
                 oninput="speedPreview(this.value)" onchange="applySpeed(this.value)">
          <span class="value" id="speedValue">0.50</span>
        </div>
        <div class="speed-presets">
          <button class="btn" id="btnSlow" onclick="applySpeed(0.25)">Slow</button>
          <button class="btn" id="btnNormal" onclick="applySpeed(0.5)">Normal</button>
          <button class="btn" id="btnFast" onclick="applySpeed(1.0)">Fast</button>
        </div>
      </div>

      <!-- Title -->
      <div class="card">
        <h2>Title</h2>
        <div class="input-row">
          <label>Text</label>
          <input type="text" id="titleText" placeholder="Enter title..."
                 onkeydown="if(event.key==='Enter')applyTitle()">
          <button class="btn" onclick="applyTitle()">Set</button>
        </div>
        <div class="input-row">
          <label>Font</label>
          <select id="titleFont" onchange="applyFont()">
            <option value="Helvetica">Helvetica</option>
            <option value="Menlo">Menlo</option>
            <option value="Monaco">Monaco</option>
            <option value="SF Mono">SF Mono</option>
            <option value="Courier New">Courier New</option>
            <option value="Georgia">Georgia</option>
            <option value="Futura">Futura</option>
            <option value="Avenir">Avenir</option>
            <option value="Gill Sans">Gill Sans</option>
          </select>
        </div>
        <div class="input-row">
          <label>Size</label>
          <input type="number" id="titleSize" value="12" min="8" max="48" step="1"
                 onchange="applyFontSize()">
        </div>
      </div>

      <div class="status-bar">
        <span class="status-dot" id="statusDot"></span>
        <span id="statusText">Connecting...</span>
      </div>
    </div>

    <script>
    const base = window.location.origin;
    let connected = false;

    function send(path) {
      fetch(base + path).catch(() => {});
    }

    function setColor(hex) {
      send('/set-color?hex=' + hex);
      updateColorUI('#' + hex);
    }

    function applyHex() {
      let v = document.getElementById('hexInput').value.trim().replace(/^#/, '');
      if (/^[0-9A-Fa-f]{6}$/.test(v)) {
        setColor(v);
      }
    }

    function pickerChanged(val) {
      const hex = val.replace('#', '');
      send('/set-color?hex=' + hex);
      updateColorUI(val);
    }

    function updateColorUI(hex) {
      if (!hex.startsWith('#')) hex = '#' + hex;
      document.getElementById('colorPreview').style.background = hex;
      document.getElementById('colorPreview').style.boxShadow = '0 0 20px ' + hex + '66';
      document.getElementById('hexInput').value = hex.toUpperCase();
      document.getElementById('colorPicker').value = hex;
    }

    function speedPreview(val) {
      document.getElementById('speedValue').textContent = parseFloat(val).toFixed(2);
      updateSpeedButtons(parseFloat(val));
    }

    function applySpeed(val) {
      val = parseFloat(val);
      send('/set-speed?value=' + val);
      document.getElementById('speedSlider').value = val;
      document.getElementById('speedValue').textContent = val.toFixed(2);
      updateSpeedButtons(val);
    }

    function updateSpeedButtons(val) {
      document.getElementById('btnSlow').classList.toggle('active', Math.abs(val - 0.25) < 0.01);
      document.getElementById('btnNormal').classList.toggle('active', Math.abs(val - 0.5) < 0.01);
      document.getElementById('btnFast').classList.toggle('active', Math.abs(val - 1.0) < 0.01);
    }

    function applyTitle() {
      const text = document.getElementById('titleText').value;
      send('/set-title?text=' + encodeURIComponent(text));
    }

    function applyFont() {
      const font = document.getElementById('titleFont').value;
      send('/set-title-font?name=' + encodeURIComponent(font));
    }

    function applyFontSize() {
      const size = document.getElementById('titleSize').value;
      send('/set-title-font-size?value=' + size);
    }

    function rgbToHex(r, g, b) {
      const toHex = v => {
        const h = Math.round(v * 255).toString(16);
        return h.length === 1 ? '0' + h : h;
      };
      return '#' + toHex(r) + toHex(g) + toHex(b);
    }

    function pollStatus() {
      fetch(base + '/status')
        .then(r => r.json())
        .then(data => {
          connected = true;
          document.getElementById('statusDot').className = 'status-dot connected';
          document.getElementById('statusText').textContent = 'Connected';

          if (data.color) {
            const hex = rgbToHex(data.color.r, data.color.g, data.color.b);
            updateColorUI(hex);
          }
          if (data.speed !== undefined) {
            const s = parseFloat(data.speed);
            document.getElementById('speedSlider').value = s;
            document.getElementById('speedValue').textContent = s.toFixed(2);
            updateSpeedButtons(s);
          }
          if (data.title !== undefined) {
            document.getElementById('titleText').value = data.title;
          }
          if (data.titleFont) {
            const sel = document.getElementById('titleFont');
            for (let i = 0; i < sel.options.length; i++) {
              if (sel.options[i].value === data.titleFont) {
                sel.selectedIndex = i;
                break;
              }
            }
          }
          if (data.titleFontSize !== undefined) {
            document.getElementById('titleSize').value = data.titleFontSize;
          }
        })
        .catch(() => {
          connected = false;
          document.getElementById('statusDot').className = 'status-dot disconnected';
          document.getElementById('statusText').textContent = 'Disconnected';
        });
    }

    pollStatus();
    setInterval(pollStatus, 3000);
    </script>
    </body>
    </html>
    """
}
