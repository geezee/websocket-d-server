import std.stdio;
import std.uuid;

import server;

class EchoSocketServer : WebSocketServer {

    override void onOpen(UUID s) {}
    override void onClose(UUID s) {}
    override void onBinaryMessage(UUID s, ubyte[] msg) {}

    override void onTextMessage(UUID s, string msg) {
        writefln("[DEBUG] received message from %s", s);
        writefln("[DEBUG]         message: %s", msg);
        writefln("[DEBUG]         message length: %d", msg.length);
        sendText(s, msg);
    }

}

class BroadcastServer : WebSocketServer {

    byte[UUID] peers;

    override void onBinaryMessage(UUID s, ubyte[] msg) {}

    override void onOpen(UUID s) {
        peers[s] = 0;
    }

    override void onClose(UUID s) {
        peers.remove(s);
    }

    override void onTextMessage(UUID src, string msg) {
        foreach (uuid,_; peers) if (uuid != src) sendText(uuid, msg);
    }
}

void main() {
    WebSocketServer manager = new BroadcastServer();
    manager.run();
}

