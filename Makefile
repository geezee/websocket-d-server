CC=ldc2
CFLAGS=--release -O3

test_server: server.o frame.o request.o checkpoint.o test_server.o
	$(CC) $(CFLAGS) server.o frame.o request.o checkpoint.o test_server.o -of=test_server

server.o: server.d
	$(CC) $(CFLAGS) -c server.d

frame.o: frame.d checkpoint.d
	$(CC) $(CFLAGS) -c frame.d checkpoint.d

request.o: request.d checkpoint.d
	$(CC) $(CFLAGS) -c request.d checkpoint.d

checkpoint.o: checkpoint.d
	$(CC) $(CFLAGS) -c checkpoint.d

test_server.o: test_server.d
	$(CC) $(CFLAGS) -c test_server.d

clean:
	rm server.o frame.o request.o checkpoint.o test_server.o test_server
