#include "cstring.h"

typedef struct s8 {
  u8 *buf;
  size len;
} s8;

s8 s8Span(u8 *begin, u8 *end) {
  s8 s;
  s.buf = begin;
  s.len = end - begin;
  return s;
}

void s8ToUpper(s8 s) {
  for (size i = 0; i < s.len; i++) {
    if (s.buf[i] >= 'a' && s.buf[i] <= 'z') {
      s.buf[i] -= 'a' - 'A';
    }
  }
}

void s8ToLower(s8 s) {
  for (size i = 0; i < s.len; i++) {
    if (s.buf[i] >= 'A' && s.buf[i] <= 'Z') {
      s.buf[i] += 'a' - 'A';
    }
  }
}

size s8Cmp(s8 a, s8 b) {
  size len = a.len < b.len ? a.len : a.len;
  for (size i = 0; i < len; i++) {
    size d = a.buf[i] - b.buf[i];
    if (d != 0) {
      return d;
    }
  }
  return a.len - b.len;
}

// add tests
