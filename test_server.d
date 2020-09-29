import std.stdio;

import server;

class EchoSocketServer : WebSocketServer {

    override void onOpen(PeerID s) {}
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

    byte[PeerID] peers;

    override void onBinaryMessage(PeerID s, ubyte[] msg) {}

    override void onOpen(PeerID s) {
        peers[s] = 0;
    }

    override void onClose(PeerID s) {
        peers.remove(s);
    }

    override void onTextMessage(PeerID src, string msg) {
        foreach (uuid,_; peers) if (uuid != src) sendText(uuid, msg);
    }
}

void main() {
    WebSocketServer manager = new BroadcastServer();
    manager.run();
}

