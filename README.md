# simple-web-server

A minimal HTTP/1.0 server written in pure x86-64 assembly — Linux syscalls only, no libc.

It's a learning project: no error handling, no security mitigations. Request paths are passed straight to `open()`, so it's trivially vulnerable to path traversal. That's left in on purpose as a demonstration.

## Path traversal

<img width="1345" height="852" alt="new_image" src="https://github.com/user-attachments/assets/09c4fe88-5973-4025-b743-5c03410721f1" />

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
