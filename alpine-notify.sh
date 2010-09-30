#!/bin/sh

exec perl -I"${HOME}"/git/alpine-notify/lib -I"${HOME}"/git/funperl/lib "${HOME}"/git/alpine-notify/alpine-notify.pl "$@"
