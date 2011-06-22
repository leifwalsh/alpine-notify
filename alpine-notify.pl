#!/usr/bin/perl

use warnings;
use strict;

use AlpineNotify::Notifier qw(register);
use Funperl::Dbg qw(debug trace);

sub send_notification($$$) {
  my ($from, $subject, $folder) = @_;

  system("notify-send", "-c", "email.arrived", "-i",
         "/usr/share/icons/Faenza/mimetypes/scalable/message.svg",
         "New message in $folder",
         "From: $from\nSubject: $subject");
}

sub main() {
  my @args = ();
  for my $a (@ARGV) {
    if ($a =~ m/-D|--debug/) {
      debug(1);
    } elsif ($a =~ m/-T|--trace/) {
      trace(1);
    } elsif ($a =~ m/-h|--help/) {
      use File::Basename;
      my $prog = basename($0);
      print STDERR "Usage: $prog [/path/to/alpine-fifo-dir/ [alpine-fifo-name]]", $/;
      exit(2);
    } else {
      push @args, $a;
    }
  }
  if (@args > 2) {
    use File::Basename;
    my $prog = basename($0);
    print STDERR "Usage: $prog [/path/to/alpine-fifo-dir/ [alpine-fifo-name]]", $/;
    exit(2);
  }
  my ($dir, $name) = @args;

  register(\&send_notification, $dir, $name);
}

main();

__END__

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
