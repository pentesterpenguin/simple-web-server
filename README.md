# simple-web-server

A minimal HTTP/1.0 server written in pure x86-64 assembly — Linux syscalls only, no libc.

It's a learning project: no error handling, no security mitigations. Request paths are passed straight to `open()`, so it's trivially vulnerable to path traversal. That's left in on purpose as a demonstration.

## Path traversal

<img width="1862" height="880" alt="path traversal demo" src="https://github.com/user-attachments/assets/b0e69614-bd06-43df-b9fe-5da62935a876" />

Request used:

```
GET /../../../../etc/passwd HTTP/1.1
```

## Build & run

```bash
docker build -t asmhttp .
docker run --rm -p 8080:80 asmhttp
```

Then from another terminal:

```bash
printf 'GET /../../../../etc/passwd HTTP/1.1\r\n\r\n' | nc 127.0.0.1 8080
```
