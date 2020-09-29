import std.stdio;
import std.uuid;

import server;

class MySocketManager : SocketManager {

    override void onOpen(UUID s) {
        writefln("OPENED CONNECTION WITH %s", s);
    }

    override void onClose(UUID s) {
        writefln("CLOSE CONNECTION WITH %s", s);
    }

    override void onTextMessage(UUID s, string msg) {
        writefln("[DEBUG] received message from %s", s);
        writefln("[DEBUG]         message: %s", msg);
        writefln("[DEBUG]         message length: %d", msg.length);
    }

    override void onBinaryMessage(UUID s, ubyte[] msg) {
    }

}

void main() {
    SocketManager manager = new MySocketManager();
    manager.run();
}

