FROM ubuntu:24.04 AS build
RUN apt-get update && apt-get install -y binutils
WORKDIR /src
COPY server.s .
RUN as -o server.o server.s && ld -o server server.o

FROM ubuntu:24.04
COPY --from=build /src/server /server
# a couple of files so a "normal" GET has something to serve
RUN echo '<h1>hello from asm</h1>' > /index.html
EXPOSE 80
CMD ["/server"]
