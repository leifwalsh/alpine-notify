#!/usr/bin/perl

use warnings;
use strict;

package AlpineNotify::Notifier;

=pod

=head1 NAME

AlpineNotify::Notifier - Register a notification for alpine.

=head1 SYNOPSIS

    use AlpineNotify::Notifier qw(register;
    
    sub myfn($$$) {
      my ($from, $subject, $folder) = @_;
      alert_user_of_a_message($from, $subject, $folder);
    }
    
    register(\&myfn, $fifo_dir, $fifo_name);

=head1 DESCRIPTION

Watches the alpine fifo (defaults to /tmp/alpine-fifo) for data from alpine
regarding new mail.  You provide a callback that does something with the From
and Subject headers, and the folder it came in to.

See F<alpine-notify.pl> in the top level of this source tree for an example that
uses the Ubuntu notifications framework.

=cut

our @EXPORT_OK;
BEGIN {
  use Exporter qw(import);

  @EXPORT_OK = qw(register);
}

use File::Spec qw(catfile);
use Linux::Inotify2;

use Funperl::Dbg qw(dbg tr_enter tr_exit);

our $ALPINE_FIFO_DIR = "/tmp";
our $ALPINE_FIFO_NAME = "alpine-fifo";

our $alpine_fifo_path;

our $ino = new Linux::Inotify2
  or die "couldn't create inotify object: $!";
$ino->blocking(1);

=head1 FUNCTIONS

=over

=item C<register \&callback[, $dir[, $name]]>

Registers your C<callback> to receive notifications.  You can also provide a
different fifo path from the default, in C<$dir> and C<$name>.

=back

=cut

sub register($;$$) {
  &tr_enter;

  my ($cb, $dir, $name) = @_;

  $ALPINE_FIFO_DIR = $dir if defined($dir);
  $ALPINE_FIFO_NAME = $name if defined($name);
  $alpine_fifo_path = File::Spec->catfile($ALPINE_FIFO_DIR,
                                          $ALPINE_FIFO_NAME);

  open_fifo(\&handle_fifo, $cb);

  tr_exit;
}

sub just_open() {
  &tr_enter;

  open my $fh, "<:utf8", $alpine_fifo_path
    or die "couldn't open fifo $alpine_fifo_path: $!";
  dbg("opened $alpine_fifo_path");

  tr_exit($fh);
}

sub open_fifo($$) {
  &tr_enter;

  my ($cb, @args) = @_;

  if (-p $alpine_fifo_path) {
    dbg("$alpine_fifo_path exists already");
    $cb->(just_open(), @args);
  } else {
    dbg("setting a watch on $ALPINE_FIFO_DIR");
    my $watch = $ino->watch($ALPINE_FIFO_DIR, IN_CREATE, sub {
                           &tr_enter;

                           dbg("got an event");
                           my ($e) = @_;
                           if ($e->IN_CREATE and
                               $e->name eq $ALPINE_FIFO_NAME) {
                             dbg("got the right event");
                             $e->w->cancel();
                             $cb->(just_open(), @args);
                           } elsif ($e->IN_UNMOUNT or $e->IN_IGNORED) {
                             $e->w->cancel();
                           }

                           tr_exit;
                         })
      or die "couldn't set a watch on $ALPINE_FIFO_DIR: $!";
    1 while $ino->poll();
  }

  tr_exit;
}

sub handle_fifo($$) {
  &tr_enter;

  my ($fh, $cb) = @_;

  my ($frompos, $fromlength,
      $subjectpos, $subjectlength,
      $folderpos, $folderlength);

  while (<$fh>) {
    chomp;
    dbg("read a line:");
    dbg($_);

    next if (m/^New Mail window started at/ or
             m/^-+$/);
    if (m/^(((\s+)(From:\s+))(Subject:\s+))(Folder:\s*)$/) {
      dbg("reading positions");
      $frompos = length($3);
      $fromlength = length($4);
      $subjectpos = length($2);
      $subjectlength = length($5);
      $folderpos = length($1);
      $folderlength = length($6);
    } else {
      my ($from) = ($_ =~ m/.{$frompos}(.{$fromlength})/);
      $from =~ s/\s*$//;
      my ($subject) = (m/.{$subjectpos}(.{$subjectlength})/);
      $subject =~ s/\s*$//;
      chomp($subject);
      my ($folder) = (m/.{$folderpos}(.{$folderlength})/);
      $folder =~ s/\s*$//;

      $cb->($from, $subject, $folder);
    }
  }

  dbg("read from $alpine_fifo_path failed, probably EOF.");
  dbg("closing $alpine_fifo_path");
  close $fh
    or die "couldn't close $ALPINE_FIFO_NAME: $!";

  dbg("restarting watcher");
  open_fifo(\&handle_fifo, $cb);

  tr_exit;
}

1;

__END__

=head1 CAVEATS

If you start this notifications watcher after some data has been read out of the
fifo, it will break, because it needs to look at the headers to determine the
width of the fields in each line.  You'll get undefined reference errors if you
do this.

To avoid this, if you for some reason need to restart the notifier, you can
either look at the code and hard-code some field widths in (it's in the middle
of handle_fifo if you care), or you can just kill alpine and restart it after
you start the notifier up.

In theory, this is fixable if we read the fifo text width out of the user's
F<.pinerc>, and knew the algorithm alpine uses for calculating field widths, but
I don't know that algorithm, so if someone does I'd love to see a patch.

=head1 TODO

See the end of L<CAVEATS>.

=head1 DEPENDENCIES

L<Funperl::Dbg>,
L<Linux::Inotify2>,
L<File::Spec>

=head1 COPYRIGHT

Copyright 2010 Leif Walsh <leif.walsh@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the <organization> nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
