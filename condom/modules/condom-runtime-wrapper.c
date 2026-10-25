#define _POSIX_C_SOURCE 200809L
#include <elf.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

int main(int argc, char **argv) {
    int executable = open(CONDOM_BINARY, O_RDONLY | O_CLOEXEC);
    if (executable < 0) {
        perror(CONDOM_BINARY);
        return EXIT_FAILURE;
    }

    char magic[SELFMAG];
    ssize_t bytes_read = read(executable, magic, sizeof(magic));
    if (bytes_read < 0) {
        perror(CONDOM_BINARY);
        return EXIT_FAILURE;
    }
    if (bytes_read != SELFMAG || memcmp(magic, ELFMAG, SELFMAG) != 0) {
        fprintf(stderr, "%s: refusing to execute a non-ELF Condom binary\n", CONDOM_BINARY);
        return EXIT_FAILURE;
    }

    char *replacement_argv[] = {CONDOM_BINARY, NULL};
    if (argc == 0) {
        argv = replacement_argv;
    } else {
        argv[0] = CONDOM_BINARY;
    }

    fexecve(executable, argv, environ);
    perror(CONDOM_BINARY);
    return EXIT_FAILURE;
}
