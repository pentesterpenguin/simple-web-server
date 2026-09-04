.intel_syntax noprefix
.global _start

.data
response:
    .ascii "HTTP/1.0 200 OK\r\n\r\n"
response_len = . - response

.text
_start:

    # creating a socket 
    # int socket(int domain, int type, int protocol);
    mov rdi, 2 # domain = AF_INET
    mov rsi, 1 # type = SOCK_STREAM; for TCP connections
    mov rdx, 0 # protocol
    mov rax, 41 # syscall number for socket() 
    syscall

    # saving the file descriptor in r8
    mov r8, rax

    # binding
    # int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
    xor rax, rax # cleaning up the register
    push rax # pushing first 8 bytes of zeroes
    mov rax, 0x0000000050000002 # we can write 500002 directly too but this way is more explicit
    push rax # pushing the second part
    mov rdi, r8 # fd
    mov rsi, rsp # points to the stack. where the "struct sockaddr" lives
    mov rdx, 16 # addrlen
    mov rax, 49
    syscall

    # listening for incoming connections
    # int listen(int sockfd, int backlog);
    mov rdi, r8 # fd
    mov rsi, 0
    mov rax, 50
    syscall

handling:
    # accepting connections
    /* int accept(int sockfd, struct sockaddr *_Nullable restrict addr,
    socklen_t *_Nullable restrict addrlen); 
    --------------------------------
    the 2 last arguments are normally nullable (if we don't want the clients IP/port)
    so if we set them to 0 we still get the fd we need.*/
    mov rdi, r8
    xor rsi, rsi
    xor rdx, rdx
    mov rax, 43
    syscall

    # stocking the newly created fd (to communicate directly with the client)
    mov r9, rax

    # forking for concurrency
    mov rax, 57
    syscall

    # compare the value to learn who is parent/child
    /* if its the parent then it's somehting different then 0
    that's why we comapre it to 0. if it didn't work well it's -1, 
    if it worked it's the PID of the child. */ 
    cmp rax, 0
    jne parent

    # here is the else part (so child process)
    # closing the listening socket 
    mov rdi, r8
    mov rax, 3
    syscall

    # reading the request
    # ssize_t read(int fd, void buf[.count], size_t count);
    sub rsp, 0x1000
    mov r12, rsp
    mov rdi, r9 # client fd
    mov rsi, rsp # buf -> r
    mov rdx, 0x1000 # count
    xor rax, rax
    syscall

    mov r14, rax  # r14 = total bytes read

    # understand if it's a GET or a POST
    # r12 = base pointer to the request buffer (holds the raw bytes read from the client)
    mov rsi, r12
    find_method:
        cmp DWORD PTR [rsi], 0x20544547 # ' TEG' in LE or 'GET 'in normal BE   
        je get_method

        cmp DWORD PTR [rsi], 0x54534F50
        je post_method

    get_method:
        /* opening the file that the client wants. 
        but first we need to trim to only get the filename and nothing else */

        lea rdi, [r12 + 4]
        mov rsi, rdi # rsi = scanning cursor

        find_space_get:
            cmp byte ptr [rsi], 0x20   # 0x20 = ' ' (space before "HTTP/1.1")
            je  found_get
            inc rsi                    # next byte
            jmp find_space_get
        found_get:
            mov byte ptr [rsi], 0 

        # open file
        mov rsi, 0
        mov rax, 2
        syscall
        mov r10, rax

        # read(file_fd, buf, count)
        sub rsp, 0x1000            # second buffer for file contents
        mov r13, rsp               # stable base pointer to it
        mov rdi, r10               # file fd
        mov rsi, r13               # where to put the bytes  <-- this is your "where"
        mov rdx, 0x1000            # max bytes to read        <-- this is your "size"
        xor rax, rax               # read = 0
        syscall
        mov r14, rax               #

        # close the opened file
        mov rdi, r10
        mov rax, 3
        syscall

        # write the 200 OK to the client
        mov rdi, r9
        lea rsi, [rip + response]
        mov rdx, response_len
        mov rax, 1
        syscall

        # write(client_fd, buf, bytes_read)
        mov rdi, r9                # client fd
        mov rsi, r13               # same buffer we just filled
        mov rdx, r14               # the REAL count from read, not a fixed number
        mov rax, 1                 # write
        syscall

        # close fd
        mov rdi, r9
        mov rax, 3
        syscall

        # exit 
        mov rdi, 0
        mov rax, 60
        syscall

    post_method:
        # parse the path: skip "POST " (5 bytes), then null-terminate at the space
        lea rdi, [r12 + 5]         # rdi = start of filename (buf arg for open)
        mov rsi, rdi               # rsi = scanning cursor
        find_space_post:
        cmp byte ptr [rsi], 0x20   # space before "HTTP/1.1"
        je  found_post
        inc rsi
        jmp find_space_post
        found_post:
        mov byte ptr [rsi], 0      # terminate the filename

        # open(filename, O_WRONLY|O_CREAT|O_TRUNC, 0644)
        # rdi already = filename pointer
        mov rsi, 0x41              # O_WRONLY|O_CREAT
        mov rdx, 0x1FF             # mode 0777
        mov rax, 2                 # open
        syscall
        mov r10, rax               # r10 = file fd

        # find end of headers (\r\n\r\n) in the buffer
        mov rcx, r12               # rcx = cursor at buffer start
        find_body:
        cmp dword ptr [rcx], 0x0A0D0A0D   # 4 bytes == \r\n\r\n ?
        je  found_body
        inc rcx
        jmp find_body
        found_body:
        add rcx, 4                 # step past blank line -> body start

        # body_len = total_read - (body - buf)
        mov rsi, rcx               # rsi = body pointer (buf arg for write)
        sub rcx, r12               # rcx = header length
        mov rdx, r14               # rdx = total bytes
        sub rdx, rcx               # rdx = body length

        # write(file_fd, body, body_len)
        mov rdi, r10
        mov rax, 1
        syscall

        # close the file
        mov rdi, r10
        mov rax, 3
        syscall

        # write the 200 OK to the client
        mov rdi, r9
        lea rsi, [rip + response]
        mov rdx, response_len
        mov rax, 1
        syscall

        # close fd
        mov rdi, r9
        mov rax, 3
        syscall

        # exit
        mov rdi, 0
        mov rax, 60
        syscall

parent:
    # close fd
    mov rdi, r9
    mov rax, 3
    syscall

    jmp handling
