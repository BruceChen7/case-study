#!/usr/bin/env bash

# Version of libbpf to fetch headers from
LIBBPF_VERSION=1.2.2

# The headers we want
prefix=libbpf-"$LIBBPF_VERSION"
headers=(
    "$prefix"/LICENSE.BSD-2-Clause
    "$prefix"/src/bpf_endian.h
    "$prefix"/src/bpf_helper_defs.h
    "$prefix"/src/bpf_helpers.h
    "$prefix"/src/bpf_tracing.h
)

# Fetch libbpf release and extract the desired headers
# 解压缩后开始重命名下载文件
curl -sL "https://github.com/libbpf/libbpf/archive/refs/tags/v${LIBBPF_VERSION}.tar.gz" | \
    tar -xz --xform='s#.*/##' "${headers[@]}"
