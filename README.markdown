alpine-notify
=============

USAGE
-----

    % git clone git://github.com/adlaiff6/alpine-notify.git
    % git clone git://github.com/adlaiff6/funperl.git
    % cd alpine-notify
    % perl -I./lib -I../funperl/lib alpine-notify.pl &
    % cd ; alpine

DESCRIPTION
-----------

A library (in `lib/`) for handling [alpine][]'s "new message" notifications
through a FIFO, and an executable that uses this library to notify you using
Ubuntu's `notify-send`.

Put it in your startup applications!

EXTRAS
------

If you want to see debugging info, try `-D|--debug` or `-T|--trace`.

CAVEATS
-------

You should never start `alpine-notify.pl` after alpine has already started.
There are cases where this is okay, but in general, if you need to start the
notifier, kill alpine first, start it, then restart alpine.  See the
documentation for `AlpineNotify::Notifier` for the explanation why this is.

However, you can totally restart alpine as much as you want while this is
running, it'll handle that just fine.

BUGS
----

Yeah, probably.  Fork me.

AUTHORS
-------

 * Leif Walsh <leif.walsh@gmail.com>

COPYRIGHT
---------

3-clause BSD, see code comments.
