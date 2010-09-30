alpine-notify
=============

USAGE
-----

    % [sudo] cpan Linux::Inotify2
    % cd ~/git
    % git clone git://github.com/adlaiff6/alpine-notify.git
    % git clone git://github.com/adlaiff6/funperl.git
    % cd alpine-notify
    % ./alpine-notify.sh &
    % cd ; alpine

DESCRIPTION
-----------

A library (in `lib/`) for handling [alpine][]'s "new message" notifications
through a FIFO, and an executable that uses this library to notify you using
Ubuntu's `notify-send`.

Put it in your startup applications!

Oh, and you'll have to make sure your alpine config is set to use a fifo, and it
points to the same thing that `alpine-notify.pl` points to.  Default is
`/tmp/alpine-fifo`.

[alpine]: http://www.washington.edu/alpine/

EXTRAS
------

You should modify `alpine-notify.sh` to suit your environment (namely, point the
include directories to your copies of my git repositories), or, optionally, send
someone to tell me how to put my code on CPAN.

If you want to see debugging info, try `-D|--debug` or `-T|--trace`.

BUGS
----

If you start alpine-notify, then start alpine, but receive no new mail before
you close alpine, and then start alpine again before restarting alpine-notify,
you won't receive new notifications for that session.  The technical reason for
this is discussed in the code, and it is fixable, I just need to take some time
to do it right.

However, as long as you receive at least one new mail in each alpine session,
alpine-notify can stay running as long as you want behind all of alpine's quits
and restarts.

TODO
----

Fix bugs.  Fork me.

AUTHORS
-------

 * Leif Walsh <leif.walsh@gmail.com>

COPYRIGHT
---------

3-clause BSD, see code comments.
