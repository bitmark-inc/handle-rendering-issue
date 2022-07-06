# syntax=docker/dockerfile:1.2

# SPDX-License-Identifier: ISC
# Copyright (c) 2019-2021 Bitmark Inc.
# Use of this source code is governed by an ISC
# license that can be found in the LICENSE file.

FROM alpine:3.16 as build

RUN apk add --no-cache curl-dev janet janet-dev gcc musl-dev make git

# fix janet library links
RUN ln -s libjanet.so.1.19.2 /usr/lib/libjanet.a || true
RUN ln -s libjanet.so.1.19.2 /usr/lib/libjanet.so.1 || true
RUN ln -s libjanet.so.1.19.2 /usr/lib/libjanet.so.1.19 || true

WORKDIR /Build

RUN git clone --depth=1 https://github.com/janet-lang/jpm.git
RUN cd jpm && env PREFIX=/usr janet bootstrap.janet

WORKDIR hri
COPY . .

RUN make all

# ---

FROM alpine:3.16

RUN apk add --no-cache curl janet

# fix janet library links
RUN ln -s libjanet.so.1.19.2 /usr/lib/libjanet.so.1 || true
RUN ln -s libjanet.so.1.19.2 /usr/lib/libjanet.so.1.19 || true


COPY LICENSE README.md /

#COPY entrypoint.sh /entrypoint.sh
COPY --from=build /Build/hri/build/handle-rendering-issue /handle-rendering-issue

#ENTRYPOINT ["/entrypoint.sh"]
ENTRYPOINT ["/handle-rendering-issue"]
