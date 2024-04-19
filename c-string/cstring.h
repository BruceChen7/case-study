#ifndef __C_STRING_H__
#define __C_STRING_H__
#pragma once
// https://github.com/skeeto/scratch/blob/master/misc/treap.c
#include <stddef.h>
#include <stdint.h>

typedef uint8_t u8;
typedef int32_t b32;
typedef int32_t i32;
typedef uint64_t u64;
typedef char byte;
typedef size_t usize;
typedef ptrdiff_t size;

#define sizeof(x) (size)sizeof(x)
#define alignof(x) (size) _Alignof(x)
#define countof(x) (size)sizeof(x) / sizeof(*x)
#define lengthof(s) (countof(s) - 1)

#define S(s)                                                                   \
  (s8) { (u8 *)(s), lengthof(s) }

typedef struct s8 s8;

s8 s8Span(u8 *begin, u8 *end);

size s8Cmp(s8 a, s8 b);

#endif //
