#!/bin/perl

# convert a mode 7 screen to an assembler source code constants block

sub usage
{
  print STDERR "mo72asm <in> <out> <label>\n";
  exit -1;
}

if (scalar @ARGV != 3)
{
  usage;
}

my ($fn_in, $fn_out, $asm_label) = @ARGV;

open(my $f_in, "<", $fn_in) or die "Cannot open $fn_in";
open(my $f_out, ">", $fn_out) or die "Cannot open $fn_in";

print $f_out "        .segment \"CODE0\"\n";
print $f_out "        .export $asm_label\n";
print $f_out "$asm_label:\n";

my $last_ch = -1;
my $last_ch_count = 0;
my $count = 0;

while ($count <= 1000) {
  my $n = read($f_in, my $c, 1);
  my $ch = ord($c);
  if ($last_ch_count >= 31 || $ch != $last_ch || $count == 1024 || $n == 0)
  {
    if ($last_ch_count > 1 || ($last_ch >= 0 && $last_ch < 32))
    {
      print $f_out "        .byte $last_ch_count\n";
      print $f_out "        .byte $last_ch\n";
    }
    elsif ($last_ch != -1)
    {
      print $f_out "        .byte $last_ch\n"; 
    }
    
    if ($n == 0)
    {
      while ($count < 1000)
      {
        my $ct = 1024 - $count;
        if ($ct > 31) {
          $ct = 31;
        }
        print $f_out "        .byte $ct\n";
        print $f_out "        .byte 0\n";
        
        $count+=$ct;
      }
    }
    $last_ch = $ch;
    $last_ch_count = 1;
  } else {
    $last_ch_count++;
  }
  $count++;
  if ($n == 0) {
    last;
    print "last";
  }
}