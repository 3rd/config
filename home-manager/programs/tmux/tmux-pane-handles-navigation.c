#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <regex.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  char name[256];
  char state;
  int tty;
  int foregroundGroup;
} Process;

static bool matchesProcessName(long pid, const regex_t *commandPattern) {
  char path[64];
  snprintf(path, sizeof(path), "/proc/%ld/comm", pid);
  FILE *file = fopen(path, "r");
  if (file == NULL) return false;

  char name[256];
  size_t length = fread(name, 1, sizeof(name) - 1, file);
  bool hasError = ferror(file);
  fclose(file);
  if (hasError || length == 0 || name[length - 1] != '\n') return false;

  name[length - 1] = '\0';
  return regexec(commandPattern, name, 0, NULL, 0) == 0;
}

static bool readProcess(long pid, Process *process) {
  char path[64];
  snprintf(path, sizeof(path), "/proc/%ld/stat", pid);
  FILE *file = fopen(path, "r");
  if (file == NULL) return false;

  char stat[4096];
  size_t length = fread(stat, 1, sizeof(stat) - 1, file);
  bool hasError = ferror(file);
  fclose(file);
  if (hasError || length == 0) return false;

  stat[length] = '\0';
  char *nameStart = strchr(stat, '(');
  char *nameEnd = strrchr(stat, ')');
  if (nameStart == NULL || nameEnd == NULL || nameEnd <= nameStart) return false;

  size_t nameLength = (size_t)(nameEnd - nameStart - 1);
  if (nameLength >= sizeof(process->name)) return false;
  if (sscanf(nameEnd + 1, " %c %*d %*d %*d %d %d", &process->state, &process->tty,
             &process->foregroundGroup) != 3) return false;

  memcpy(process->name, nameStart + 1, nameLength);
  process->name[nameLength] = '\0';
  return true;
}

static bool canHandleNavigation(const Process *process, int paneTty, const regex_t *commandPattern) {
  return process->tty == paneTty && strchr("TtXxZz", process->state) == NULL &&
         regexec(commandPattern, process->name, 0, NULL, 0) == 0;
}

int main(int argc, char **argv) {
  if (argc != 3) return 2;

  char *pidEnd;
  errno = 0;
  long panePid = strtol(argv[1], &pidEnd, 10);
  if (errno != 0 || *pidEnd != '\0' || panePid <= 0 || panePid > INT_MAX) return 2;

  Process pane;
  if (!readProcess(panePid, &pane)) return 1;

  regex_t commandPattern;
  if (regcomp(&commandPattern, argv[2], REG_EXTENDED | REG_ICASE | REG_NOSUB) != 0) return 2;

  Process foreground;
  bool hasForegroundProcess = pane.foregroundGroup > 0 && readProcess(pane.foregroundGroup, &foreground);
  if (hasForegroundProcess && canHandleNavigation(&foreground, pane.tty, &commandPattern)) {
    regfree(&commandPattern);
    return 0;
  }

  DIR *directory = opendir("/proc");
  if (directory == NULL) {
    regfree(&commandPattern);
    return 2;
  }

  int result = 1;
  struct dirent *entry;

  while ((entry = readdir(directory)) != NULL) {
    char *entryEnd;
    long processPid = strtol(entry->d_name, &entryEnd, 10);
    if (*entryEnd != '\0' || processPid <= 0) {
      continue;
    }

    if (!matchesProcessName(processPid, &commandPattern)) {
      continue;
    }

    Process process;
    if (!readProcess(processPid, &process)) {
      continue;
    }

    if (canHandleNavigation(&process, pane.tty, &commandPattern)) {
      result = 0;
      break;
    }
  }

  closedir(directory);
  regfree(&commandPattern);
  return result;
}
