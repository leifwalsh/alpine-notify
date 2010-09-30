#!/usr/bin/perl

use warnings;
use strict;

package AlpineNotify::Notifier;

=pod

=head1 NAME

AlpineNotify::Notifier - Register a notification for alpine.

=head1 SYNOPSIS

    use AlpineNotify::Notifier qw(register);
    
    sub myfn($$$) {
      my ($from, $subject, $folder) = @_;
      alert_user_of_a_message($from, $subject, $folder);
    }
    
    register(\&myfn, $fifo_dir, $fifo_name);

=head1 DESCRIPTION

Watches the alpine fifo (defaults to F</tmp/alpine-fifo>) for data from alpine
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

use Data::Dumper;
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

sub write_field_widths($$$$$$) {
  &tr_enter;

  my ($frompos, $fromlength,
      $subjectpos, $subjectlength,
      $folderpos, $folderlength) = @_;

  open my $fh, ">", "/tmp/AlpineNotify_Notifier_config.dump"
    or die "couldn't open /tmp/AlpineNotify_Notifier_config.dump: $!";
  print $fh Data::Dumper->Dump([$frompos, $fromlength,
                                $subjectpos, $subjectlength,
                                $folderpos, $folderlength],
                               [qw(frompos fromlength
                                   subjectpos subjectlength
                                   folderpos folderlength)]);
  close $fh
    or die "couldn't close /tmp/AlpineNotify_Notifier_config.dump: $!";
  dbg("wrote new field widths to /tmp/AlpineNotify_Notifier_config.dump");

  tr_exit;
}

sub read_field_widths() {
  &tr_enter;

  die "no saved field widths, you must kill alpine and restart the notifier " .
    "before you restart alpine"
      unless -f "/tmp/AlpineNotify_Notifier_config.dump";

  my ($frompos, $fromlength,
      $subjectpos, $subjectlength,
      $folderpos, $folderlength);
  my $data = do {
    local (@ARGV, $/) = "/tmp/AlpineNotify_Notifier_config.dump";
    <>
  };
  eval($data);
  dbg("read old field widths from temp file");

  tr_exit($frompos, $fromlength,
          $subjectpos, $subjectlength,
          $folderpos, $folderlength);
}

sub calculate_field_widths($) {
  &tr_enter;

  my ($line) = @_;

  my ($frompos, $fromlength,
      $subjectpos, $subjectlength,
      $folderpos, $folderlength);
  if ($line =~ m/^(((\s+)(From:\s+))(Subject:\s+))(Folder:\s*)$/) {
    dbg("reading field widths from input");
    $frompos = length($3);
    $fromlength = length($4);
    $subjectpos = length($2);
    $subjectlength = length($5);
    $folderpos = length($1);
    $folderlength = length($6);
  }

  write_field_widths($frompos, $fromlength,
                     $subjectpos, $subjectlength,
                     $folderpos, $folderlength);

  tr_exit($frompos, $fromlength,
          $subjectpos, $subjectlength,
          $folderpos, $folderlength);
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
      ($frompos, $fromlength,
       $subjectpos, $subjectlength,
       $folderpos, $folderlength) = calculate_field_widths($_);
    } else {
      unless (defined($frompos)) {
        ($frompos, $fromlength,
         $subjectpos, $subjectlength,
         $folderpos, $folderlength) = read_field_widths();
      }
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

=head1 BUGS

If you open alpine but receive no new mail, and then close alpine, nothing gets
written to the FIFO, but this code doesn't realize that it got deleted, so the
next time you fire up alpine, it'll make a new FIFO but this code will still
have a filehandle to the wrong (nonexistent) FIFO.  This is a pretty big
problem.

=head1 TODO

See L<BUGS>.

=head1 DEPENDENCIES

L<Funperl::Dbg>,
L<Linux::Inotify2>

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
