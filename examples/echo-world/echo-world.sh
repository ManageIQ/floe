#!/usr/bin/env sh

# docker run -t -i --rm -e STATUS=1 -e ERROR=error -e MESSAGE=abc kbrock/echo-world

[ -n "${ERROR}" ]   && echo ${ERROR} >&2
[ -n "${MESSAGE}" ] && echo ${MESSAGE}
exit ${STATUS:-0}
