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
