#!/usr/bin/perl
use strict; use warnings;
my $D = shift;                       # datain dir
# ---- read side per pad from top.io ----
my %side;
open(my $io,"<","$D/top.io") or die; 
while(<$io>){ if(/^Pad:\s+(\S+)\s+(N|S|E|W)\s*$/){ $side{$1}=$2; } }
close($io);
# ---- read current top.v ----
open(my $v,"<","$D/top.v") or die; my @L=<$v>; close($v);
# split: everything up to and including the "endmodule" that closes module top,
# vs the core (module ASIC_Top ... onward).
my ($topend);
for my $i (0..$#L){ if($L[$i]=~/^endmodule/){ $topend=$i; last; } }
die "no endmodule for top" unless defined $topend;
my @core = @L[$topend+1 .. $#L];        # ASIC_Top + cells, untouched
my @head;                               # module top header + wires + I0 (keep) ; drop pad instances
for my $i (0..$topend-1){
  my $l=$L[$i];
  next if $l =~ /^(PDDW04DGZ|PVDD|PVSS|PCORNER)/;   # drop old pad instances
  push @head,$l;
}
# ---- build new pad instances (module-wrapped) ----
my @pads;
for my $i (0..$topend-1){
  my $l=$L[$i]; chomp $l;
  if($l =~ /^PDDW04DGZ_[HV]\s+(\S+)\s*\(\s*\.I\(([^)]*)\),\s*\.OEN\((1'b[01])\).*?\.PAD\(([^)]*)\),\s*\.C\(([^)]*)\)/){
    my($inst,$ipin,$oen,$pad,$cpin)=($1,$2,$3,$4,$5);
    my $sd = $side{$inst} // 'N';
    my $hv = ($sd eq 'E' || $sd eq 'W') ? 'v' : 'h';
    if($oen eq "1'b1"){ push @pads, "cpad_$hv $inst ( .PAD($pad), .C($cpin) );\n"; }   # input
    else             { push @pads, "tpad_$hv $inst ( .PAD($pad), .I($ipin) );\n"; }     # output
  } elsif($l =~ /^PVSS1DGZ_\S+\s+(\S+)\s*\(/){ push @pads,"pvss1 $1 ();\n"; }
    elsif($l =~ /^PVSS2DGZ_\S+\s+(\S+)\s*\(/){ push @pads,"pvss2 $1 ();\n"; }
    elsif($l =~ /^PVDD1DGZ_\S+\s+(\S+)\s*\(/){ push @pads,"pvdd1 $1 ();\n"; }
    elsif($l =~ /^PVDD2DGZ_\S+\s+(\S+)\s*\(/){ push @pads,"pvdd2 $1 ();\n"; }
    elsif($l =~ /^PVDD2POC_\S+\s+(\S+)\s*\(/){ push @pads,"ppoc $1 ();\n"; }
    elsif($l =~ /^PCORNER\s+(\S+)\s*\(/){ push @pads,"pcorner $1 ();\n"; }
}
# ---- pads.v : module definitions (control pins tied to shared constants) ----
my $padsv = <<'EOP';
// ===== pads.v : 28nm pad wrappers (manual style) - control pins tied inside =====
module cpad_h(C, PAD); output C; input PAD; wire c1,c0; assign c1=1'b1; assign c0=1'b0;
  PDDW04DGZ_H I1(.I(c0), .OEN(c1), .REN(c1), .PAD(PAD), .C(C)); endmodule
module cpad_v(C, PAD); output C; input PAD; wire c1,c0; assign c1=1'b1; assign c0=1'b0;
  PDDW04DGZ_V I1(.I(c0), .OEN(c1), .REN(c1), .PAD(PAD), .C(C)); endmodule
module tpad_h(PAD, I); output PAD; input I; wire c1,c0; assign c1=1'b1; assign c0=1'b0;
  PDDW04DGZ_H I1(.I(I), .OEN(c0), .REN(c0), .PAD(PAD), .C()); endmodule
module tpad_v(PAD, I); output PAD; input I; wire c1,c0; assign c1=1'b1; assign c0=1'b0;
  PDDW04DGZ_V I1(.I(I), .OEN(c0), .REN(c0), .PAD(PAD), .C()); endmodule
module pvdd1(); PVDD1DGZ_H I1(); endmodule   // core VDD  (VDDC)
module pvss1(); PVSS1DGZ_H I1(); endmodule   // core VSS  (VSSC)
module pvdd2(); PVDD2DGZ_H I1(); endmodule   // IO   VDD  (VDDP)
module pvss2(); PVSS2DGZ_H I1(); endmodule   // IO   VSS  (VSSP)
module ppoc();  PVDD2POC_V I1(); endmodule   // POC clamp
module pcorner(); PCORNER I1(); endmodule
EOP
# ---- write new top.v = pads.v + head + pad instances + endmodule + core ----
open(my $out,">","$D/top.v.new") or die;
print $out $padsv, "\n";
print $out @head;
print $out "\n// ---- IO / power / corner pads (module-wrapped) ----\n";
print $out @pads;
print $out "endmodule\n";
print $out @core;
close($out);
# ---- top.io with /I1 suffix on every pad name ----
open(my $i2,"<","$D/top.io") or die; open(my $o2,">","$D/top.io.new") or die;
while(<$i2>){ if(/^Pad:\s+(\S+)\s+(\S+)\s*$/){ printf $o2 "Pad: %s/I1  %s\n",$1,$2; } else { print $o2 $_; } }
close($i2); close($o2);
print "GEN_OK pads=",scalar(@pads),"\n";
