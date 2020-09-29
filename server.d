import std.stdio;
import std.socket;

import config;
import request;
import frame;

alias PeerID = size_t;

class WebSocketState {
    Socket socket;
    bool handshaken;
    Frame[] frames = [];
    public immutable PeerID id;
    public immutable Address address;
    public string path;

    @disable this();

    this(PeerID id, Socket socket) {
        this.socket = socket;
        this.handshaken = false;
        this.id = id;
        this.address = cast(immutable Address) (socket.remoteAddress);
    }

    public bool performHandshake(ubyte[] message) {
        import std.base64 : Base64;
        import std.digest.sha : sha1Of;
        import std.conv : to;
        assert (!handshaken);
        enum MAGIC = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        enum KEY = "Sec-WebSocket-Key";
        Request request = Request.parse(message);
        if (!request.done || KEY !in request.headers) return;
        this.path = request.path;
        string accept = Base64.encode(sha1Of(request.headers[KEY] ~ MAGIC)).to!string;
        assert(socket.isAlive);
        socket.send(
            "HTTP/1.1 101 Switching Protocol\r\n"
           ~ "Upgrade: websocket\r\n"
           ~ "Connection: Upgrade\r\n"
           ~ "Sec-WebSocket-Accept: " ~ accept ~ "\r\n\r\n");
        handshaken = true;
    }
}


abstract class WebSocketServer {

    private WebSocketState[PeerID] sockets;
    private Socket listener;

    abstract void onOpen(PeerID s, string path);
    abstract void onTextMessage(PeerID s, string s);
    abstract void onBinaryMessage(PeerID s, ubyte[] o);
    abstract void onClose(PeerID s);

    private static PeerID counter = 0;

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
        auto s = new WebSocketState(counter++, socket);
        writefln("[DEBUG] Accepting from %s (id=%s)", socket.remoteAddress, s.id);
        sockets[s.id] = s;
    }

    private void remove(WebSocketState socket) {
        sockets.remove(socket.id);
        writefln("[DEBUG] closing %s", socket.id);
        if (socket.socket.isAlive) socket.socket.close();
        onClose(socket.id);
    }

    private void handle(WebSocketState socket, ubyte[] message) {
        import std.conv : to;
        string processId = typeof(this).stringof ~ socket.id.to!string;
        if (socket.handshaken) {
            handleFrame(socket, processId.parse(message));
        } else {
            socket.performHandshake(message);
            if (socket.handshaken) writefln("[DEBUG] handshake done on path %s", path);
            onOpen(socket.id, socket.path);
        }
    }

    private void handleFrame(WebSocketState socket, Frame frame) {
        writefln("[DEBUG] received frame: done=%s; fin=%s; op=%s; length=%d",
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
            if (originalOp == Op.TEXT) onTextMessage(socket.id, cast(string) data);
            else if (originalOp == Op.BINARY) onBinaryMessage(socket.id, data);
        } else socket.frames ~= frame;
    }

    private void handleText(WebSocketState socket, Frame frame) {
        assert (socket.frames.length == 0);
        if (frame.fin) onTextMessage(socket.id, cast(string) frame.data);
        else socket.frames ~= frame;
    }

    private void handleBinary(WebSocketState socket, Frame frame) {
        assert (socket.frames.length == 0);
        if (frame.fin) onBinaryMessage(socket.id, frame.data);
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

    public void sendText(PeerID dest, string message) {
        if (dest !in sockets) {
            writefln("[WARN] Trying to send a message to %s which is not connected");
            return;
        }
        import std.string : representation;
        auto bytes = message.representation.dup;
        auto frame = Frame(true, Op.TEXT, false, message.length, [0,0,0,0], true, bytes);
        auto serial = frame.serialize;
        writefln("[DEBUG] Sending %d bytes to %s in one frame of %d bytes long", bytes.length, dest, serial.length);
        sockets[dest].socket.send(serial);
    }

    public void sendBinary(PeerID dest, ubyte[] message) {
        if (dest !in sockets) {
            writefln("[WARN] Trying to send a message to %s which is not connected");
            return;
        }
        auto frame = Frame(true, Op.BINARY, false, message.length, [0,0,0,0], true, message);
        auto serial = frame.serialize;
        writefln("[DEBUG] Sending %d bytes to %s in one frame of %d bytes long", message.length, dest, serial.length);
        sockets[dest].socket.send(serial);
    }

    public void run() {
        auto set = new SocketSet(MAX_CONNECTIONS+1);
        while (true) {
            set.add(listener);
            foreach (id,s; sockets) set.add(s.socket);
            Socket.select(set, null, null);

            foreach (id, socket; sockets) {
                if (!set.isSet(socket.socket)) continue;
                ubyte[BUFFER_SIZE] buffer;
                long receivedLength = socket.socket.receive(buffer[]);
                writefln("[DEBUG] Received %d bytes from %s", receivedLength, socket.id);
                if (receivedLength > 0) {
                    handle(socket, buffer[0 .. receivedLength]);
                    continue;
                }
                remove(socket);
            }

            if (set.isSet(listener)) {
                add(listener.accept());
            }

            set.reset();
        }
    }
}
