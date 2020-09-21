CC=dmd

server: server.o frame.o request.o checkpoint.o
	$(CC) server.o frame.o request.o checkpoint.o -of=server

server.o: server.d
	$(CC) -c server.d

frame.o: frame.d checkpoint.d
	$(CC) -c frame.d checkpoint.d

request.o: request.d checkpoint.d
	$(CC) -c request.d checkpoint.d

checkpoint.o: checkpoint.d
	$(CC) -c checkpoint.d
