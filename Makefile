CC=dmd

test_server: server.o frame.o request.o checkpoint.o test_server.o
	$(CC) server.o frame.o request.o checkpoint.o test_server.o -of=test_server

server.o: server.d
	$(CC) -c server.d

frame.o: frame.d checkpoint.d
	$(CC) -c frame.d checkpoint.d

request.o: request.d checkpoint.d
	$(CC) -c request.d checkpoint.d

checkpoint.o: checkpoint.d
	$(CC) -c checkpoint.d

test_server.o: test_server.d
	$(CC) -c test_server.d

clean:
	rm server.o frame.o request.o checkpoint.o test_server.o test_server
