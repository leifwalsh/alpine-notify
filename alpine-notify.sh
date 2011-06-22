#!/bin/sh

exec -a "$(basename $0)" perl -I"${HOME}"/git/alpine-notify/lib -I"${HOME}"/git/funperl/lib "${HOME}"/git/alpine-notify/alpine-notify.pl "$@"
