/* Kit launcher: one tiny static program, installed under five names
 * (singular, open-datum, devnet, cardano-node, node).
 *
 * It finds the kit root from /proc/self/exe, then starts the real
 * executable libexec/<name> through the kit's own dynamic loader with the kit's
 * own libraries (lib/<set>/), so nothing on the host's library path matters.
 * It also sets the locale (the kit carries C.UTF-8, always used), and the three
 * things the programs need to find their data and each other, unless the caller
 * already set them:
 *   singular_registry_datadir  packaged time recordings and network data
 *   E2E_GENESIS_DIR            the devnet genesis directory
 *   PATH                       the kit's bin/ first, so devnet finds cardano-node
 */
#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define LOADER "ld-linux-x86-64.so.2"

/* three library sets, each with the C library it was built against: the Haskell programs (main),
 * cardano-node (node) and Node.js, the JavaScript runtime of sink-tools (js) */
static const char *libset(const char *name) {
  if (strcmp(name, "cardano-node") == 0) return "node";
  if (strcmp(name, "node") == 0) return "js";
  return "main";
}

static int known(const char *name) {
  return !strcmp(name, "singular") || !strcmp(name, "open-datum") ||
         !strcmp(name, "devnet") || !strcmp(name, "cardano-node") ||
         !strcmp(name, "node");
}

int main(int argc, char **argv) {
  char self[PATH_MAX];
  ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
  if (n < 0) {
    fprintf(stderr, "kit launcher: cannot read /proc/self/exe: %s\n", strerror(errno));
    return 127;
  }
  self[n] = 0;

  char *slash = strrchr(self, '/');
  if (!slash) { fprintf(stderr, "kit launcher: odd path %s\n", self); return 127; }
  *slash = 0;                       /* self = <root>/bin, base follows */
  const char *name = slash + 1;
  char *bin = self;
  char root[PATH_MAX];
  snprintf(root, sizeof root, "%s", bin);
  char *rs = strrchr(root, '/');
  if (!rs) { fprintf(stderr, "kit launcher: odd path %s\n", bin); return 127; }
  *rs = 0;                          /* root = <root> */

  if (!known(name)) {
    fprintf(stderr, "kit launcher: unknown program name %s\n", name);
    return 127;
  }

  char loader[PATH_MAX], libdir[PATH_MAX], real[PATH_MAX], datadir[PATH_MAX],
      genesis[PATH_MAX];
  snprintf(libdir, sizeof libdir, "%s/lib/%s", root, libset(name));
  snprintf(loader, sizeof loader, "%s/" LOADER, libdir);
  snprintf(real, sizeof real, "%s/libexec/%s", root, name);
  snprintf(datadir, sizeof datadir, "%s/share/singular-registry", root);
  snprintf(genesis, sizeof genesis, "%s/share/genesis", root);

  /* The kit ships one locale (C.UTF-8) per library set. Without it the bundled C library
   * cannot find the host's locale and the Haskell programs fall back to ASCII, which
   * makes them fail on any non-ASCII character in their own output. */
  char locpath[PATH_MAX];
  snprintf(locpath, sizeof locpath, "%s/locale", libdir);
  setenv("LOCPATH", locpath, 1);
  setenv("LC_ALL", "C.UTF-8", 1);
  unsetenv("LANGUAGE");

  setenv("singular_registry_datadir", datadir, 0);
  setenv("E2E_GENESIS_DIR", genesis, 0);

  const char *old = getenv("PATH");
  size_t plen = strlen(bin) + 1 + (old ? strlen(old) : 0) + 2;
  char *path = malloc(plen);
  if (!path) return 127;
  if (old && *old) snprintf(path, plen, "%s:%s", bin, old);
  else snprintf(path, plen, "%s", bin);
  setenv("PATH", path, 1);

  /* ld.so --library-path DIR --argv0 NAME REAL ARGS... */
  char **nargv = calloc((size_t)argc + 8, sizeof *nargv);
  if (!nargv) return 127;
  int k = 0;
  nargv[k++] = loader;
  nargv[k++] = "--library-path";
  nargv[k++] = libdir;
  nargv[k++] = "--argv0";
  nargv[k++] = (char *)name;
  nargv[k++] = real;
  for (int i = 1; i < argc; i++) nargv[k++] = argv[i];
  nargv[k] = NULL;

  execv(loader, nargv);
  fprintf(stderr, "kit launcher: cannot start %s: %s\n", loader, strerror(errno));
  return 127;
}
