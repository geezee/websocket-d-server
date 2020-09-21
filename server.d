import std.stdio;
import std.socket;

import request;
import frame;

enum size_t MAX_CONNECTIONS = 2;
enum size_t BUFFER_SIZE = 1024;
enum ushort PORT = 6969;

class WebSocketState {
    Socket socket;
    bool handshaken;
    Frame[] frames = [];

    this(Socket socket) {
        this.socket = socket;
        this.handshaken = false;
    }

    public void performHandshake(ubyte[] message) {
        import std.base64 : Base64;
        import std.digest.sha : sha1Of;
        import std.conv : to;
        assert (!handshaken);
        enum MAGIC = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        enum KEY = "Sec-WebSocket-Key";
        Request request = Request.parse(message);
        if (!request.done) return;
        string accept = Base64.encode(sha1Of(request.headers[KEY] ~ MAGIC)).to!string;
        assert(socket.isAlive);
        socket.send(
            "HTTP/1.1 101 Switching Protocol\r\n"
           ~ "Upgrade: websocket\r\n"
           ~ "Connection: Upgrade\r\n"
           ~ "Sec-WebSocket-Accept: " ~ accept ~ "\r\n\r\n");
        handshaken = true;
    }

    public string id() @property {
        return socket.remoteAddress.toString();
    }
}


abstract class SocketManager {

    private WebSocketState[] sockets;
    private Socket listener;

    abstract void onTextMessage(Socket s, string s);
    abstract void onBinaryMessage(Socket s, ubyte[] o);

    this() {
        listener = new TcpSocket();
        listener.blocking = false;
        listener.bind(new InternetAddress(PORT));
        listener.listen(10);
    }

    private void add(Socket socket) {
        if (sockets.length >= MAX_CONNECTIONS) {
            writefln("[DEBUG] Too many connections");
            socket.close();
            return;
        }
        writefln("[DEBUG] Accepting from %s", socket.remoteAddress);
        sockets ~= new WebSocketState(socket);
    }

    private void remove(WebSocketState socket) {
        for (size_t i=0; i<sockets.length; i++)
            if (sockets[i] == socket) {
                sockets = sockets[0..i] ~ sockets[i+1..$];
                break;
            }
        writefln("[DEBUG] closing %s", socket.id);
        socket.socket.close();
    }

    private void handle(WebSocketState socket, ubyte[] message) {
        if (socket.handshaken) handleFrame(socket, parse(socket.id, message));
        else socket.performHandshake(message);
    }

    private void handleFrame(WebSocketState socket, Frame frame) {
        writefln("[DEBUG] received frame:\n\tdone=%s\n\tfin=%s\n\top=%s\n\tlength=%d",
                frame.done, frame.fin, frame.op, frame.length);
        if (!frame.done) return;
        final switch (frame.op) {
            case Op.CONT: return handleCont(socket, frame);
            case Op.TEXT: return handleText(socket, frame);
            case Op.BINARY: return handleBinary(socket, frame);
            case Op.CLOSE: return handleClose(socket, frame);
            case Op.PING: return handlePing(socket, frame);
            case Op.PONG: return handlePong(socket, frame);
        }
    }

    private void handleCont(WebSocketState socket, Frame frame) {
        assert (socket.frames.length > 0);
        if (frame.fin) {
            Op originalOp = socket.frames[0].op;
            ubyte[] data = [];
            for (size_t i=0; i<socket.frames.length; i++)
                data ~= socket.frames[i].data;
            data ~= frame.data;
            socket.frames = [];
            if (originalOp == Op.TEXT) onTextMessage(socket.socket, cast(string) data);
            else if (originalOp == Op.BINARY) onBinaryMessage(socket.socket, data);
        } else socket.frames ~= frame;
    }

    private void handleText(WebSocketState socket, Frame frame) {
        assert (socket.frames.length == 0);
        if (frame.fin) onTextMessage(socket.socket, cast(string) frame.data);
        else socket.frames ~= frame;
    }

    private void handleBinary(WebSocketState socket, Frame frame) {
        assert (socket.frames.length == 0);
        if (frame.fin) onBinaryMessage(socket.socket, frame.data);
        else socket.frames ~= frame;
    }

    private void handleClose(WebSocketState socket, Frame frame) {
        remove(socket);
    }

    private void handlePing(WebSocketState socket, Frame frame) {
        socket.socket.send(Frame(true, Op.PONG, false, 0, [0, 0, 0, 0], true, []).serialize);
    }

    private void handlePong(WebSocketState socket, Frame frame) {
        writefln("[DEBUG] Received pong from %s", socket.id);
    }

    public void run() {
        auto set = new SocketSet(MAX_CONNECTIONS+1);
        while (true) {
            set.add(listener);
            foreach (s; sockets) set.add(s.socket);
            Socket.select(set, null, null);

            for (size_t i=0; i<sockets.length; i++) {
                auto socket = sockets[i];
                if (!set.isSet(socket.socket)) continue;
                ubyte[BUFFER_SIZE] buffer;
                long receivedLength = socket.socket.receive(buffer[]);
                writefln("[DEBUG] Received %d bytes from %s", receivedLength, socket.id);
                if (receivedLength > 0) {
                    handle(socket, buffer[0 .. receivedLength]);
                    continue;
                }
                remove(socket);
                i--;
            }

            if (set.isSet(listener)) {
                add(listener.accept());
            }

            set.reset();
        }
    }
}

class MySocketManager : SocketManager {

    override void onTextMessage(Socket s, string msg) {
        writefln("[DEBUG] received message from %s", s.remoteAddress);
        writefln("[DEBUG]         message: %s", msg);
        writefln("[DEBUG]         message length: %d", msg.length);
    }

    override void onBinaryMessage(Socket s, ubyte[] msg) {
    }

}

void main() {

    SocketManager manager = new MySocketManager();

    manager.run();

}
