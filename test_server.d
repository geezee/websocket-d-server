import std.stdio;

import server;

class EchoSocketServer : WebSocketServer {

    override void onOpen(PeerID s, string path) {
        writefln("[DEBUG] peer %s connect to '%s'", s, path);
    }

    override void onClose(PeerID s) {}
    override void onBinaryMessage(PeerID s, ubyte[] msg) {}

    override void onTextMessage(PeerID s, string msg) {
        writefln("[DEBUG] received message from %s", s);
        writefln("[DEBUG]         message: %s", msg);
        writefln("[DEBUG]         message length: %d", msg.length);
        sendText(s, msg);
    }

}

class BroadcastServer : WebSocketServer {

    string[PeerID] peers;

    override void onBinaryMessage(PeerID s, ubyte[] msg) {}

    override void onOpen(PeerID s, string path) {
        peers[s] = path;
    }

    override void onClose(PeerID s) {
        peers.remove(s);
    }

    override void onTextMessage(PeerID src, string msg) {
        string srcPath = peers[src];
        foreach (uuid, path; peers)
            if (uuid != src && path == srcPath)
                sendText(uuid, msg);
    }
}

void main() {
    WebSocketServer manager = new BroadcastServer();
    manager.run();
}

