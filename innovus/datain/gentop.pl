#!/usr/bin/perl      

print "----------------------------------\n";
print " Automatic Layout Pads File Maker for TSMC 65n\n";
print " Written by Galina Sagdeev\n";
print " Updated by AGEF\n";
print " Input: <input_file_name> <module>\n";
print " Out: top.v & top.io files\n";
print "----------------------------------\n";


$fileIn = $ARGV[0];
$m_name = $ARGV[1];
$fileOutV = "top.v";
$fileOutIO = "top.io";

if (-e $fileOutV){
	`rm -f $fileOutV`;
}
else {
	`touch $fileOutV`;
}
open (O_V_FILE , ">$fileOutV") or die "cannot open $fileOutV\n";


if (-e $fileOutIO){
	`rm -f $fileOutIO`;
}
else {
	`touch $fileOutIO`;
}
open (O_IO_FILE , ">$fileOutIO") or die "cannot open $fileOutIO\n";


open (I_FILE , "<$fileIn") or die "cannot open $fileIn\n";


my $found=0;
my %in_begin;
my %in_end;
my %out_begin;
my %out_end;
my @words;
my @args;


#--------------parsing inpit file--------------------

while ($line = <I_FILE>) 
{
	chomp $line;
	$line =~ s/^\s+(.*)/$1/;
	@words= split(/\s+/,$line);
	
		
	if ($found == 0){
		if (($words[0] eq "module") and ($words[1] eq $m_name)){
			$found=1; 
		}
	}
	
	else{ #found =1
		if ($words[0] eq "endmodule"){
			$found=0;
		}
		elsif ($words[0] eq "input"){
			$line =~ s/^input\s+(.*)/$1/;
			@words= split(/\s+/,$line);
			@c = split (//,$words[0]);
			if ($c[0] eq '['){
				@b = split (/\[|\]|:|\s+/,$words[0]);
				$b[1] =~ s/^\s+(.*)/$1/;
				@tmp = split (/;/,$words[1]);
				$w=$tmp[0];
				$in_begin{$w}= $b[1];
				$in_end{$w}= $b[2];
			}
			else{
				foreach my $w (@words){	
					@tmp = split (/,|;/,$w);
					$w=$tmp[0];
					$in_begin{$w}= 0;
					$in_end{$w}= 0;
				} 
				
				@comma = split(//,$line);
				while ($comma[-1] eq ','){
					$line = <I_FILE>;
					chomp $line;
					$line =~ s/^input\s+(.*)/$1/;
					@words= @words= split(/\s+/,$line);
					foreach my $w (@words){	
						@tmp = split (/,|;/,$w);
						$w=$tmp[0];
						next if (not defined $w);
						$in_begin{$w}= 0;
						$in_end{$w}= 0;
					}
					@comma = split(//,$line);	
				} 
			}
		}
		elsif ($words[0] eq "output"){
			$line =~ s/^output\s+(.*)/$1/;
			@words= split(/\s+/,$line);
			@c = split (//,$words[0]);
			if ($c[0] eq '['){
				@b = split (/\[|\]|:|\s+/,$words[0]);
				$b[1] =~ s/^\s+(.*)/$1/;
				@tmp = split (/;/,$words[1]);
				$w=$tmp[0];			
				$out_begin{$w}= $b[1];
				$out_end{$w}= $b[2];
			}
			else{
				foreach my $w (@words){
					@tmp = split (/,|;/,$w);
					$w=$tmp[0];
					$out_begin{$w}= 0;
					$out_end{$w}= 0;
				} 
				
				@comma = split(//,$line);
				while ($comma[-1] eq ','){
					$line = <I_FILE>;
					chomp $line;
					$line =~ s/^output\s+(.*)/$1/;
					@words= @words= split(/\s+/,$line);
					foreach my $w (@words){	
						@tmp = split (/,|;/,$w);
						$w=$tmp[0];
						next if (not defined $w);
						$out_begin{$w}= 0;
						$out_end{$w}= 0;
					}
					@comma = split(//,$line);	
				} 
			}	
		}
	}	
}


#--------------creating $fileOutV file--------------------

print O_V_FILE "module top();\n";
foreach $in (sort keys %in_begin){
	if ($in_begin{$in} == $in_end{$in}){
		print O_V_FILE "wire wire_$in;\n";
	}
	else{
		print O_V_FILE "wire [$in_begin{$in}:$in_end{$in}] wire_$in;\n";
	}
}

foreach $out (sort keys %out_begin){
	if ($out_begin{$out} == $out_end{$out}){
		print O_V_FILE "wire wire_$out;\n";
	}
	else{
		print O_V_FILE "wire [$out_begin{$out}:$out_end{$out}] wire_$out;\n";
	}
}

print O_V_FILE "wire   net1000;\n";
print O_V_FILE "wire   net1001;\n\n\n";


print O_V_FILE "specify\n";
print O_V_FILE "    specparam CDS_LIBNAME  = \"testLib\";\n";
print O_V_FILE "    specparam CDS_CELLNAME = \"top\";\n";
print O_V_FILE "    specparam CDS_VIEWNAME = \"schematic\";\n";
print O_V_FILE "endspecify\n";


my $i=0;
print O_V_FILE "\n$m_name I0(";

foreach $in (sort keys %in_begin){
	if ($i != 0){
		print O_V_FILE ",";
	}
	if ($in_begin{$in} == $in_end{$in}){
		print O_V_FILE ".$in(wire_$in)\n";
	}
	else{
		print O_V_FILE ".$in(wire_$in\[$in_begin{$in}:$in_end{$in}\])\n";
	}
	$i = $i+1;
}

foreach $out (sort keys %out_begin){
	if ($i != 0){
		print O_V_FILE ",";
	}
	if ($out_begin{$out} == $out_end{$out}){
		print O_V_FILE ".$out(wire_$out)\n";
	}
	else{
		print O_V_FILE ".$out(wire_$out\[$out_begin{$out}:$out_end{$out}\])\n";
	}
	$i = $i+1;
}

print O_V_FILE ");\n";

print O_V_FILE "\n";
print O_V_FILE "pv0a PAD_G1 ( );\n";
print O_V_FILE "pv0c PAD_G3 (.VSS(VSS));\n";
print O_V_FILE "pvda PAD_I1 ( );\n";
print O_V_FILE "pvdc PAD_I3 (.VDD(VDD));\n";
print O_V_FILE "ppoc PAD_POC ();\n\n";



#------------creating in pads-------------
$i=5;
$net=100;
foreach $in (sort keys %in_begin){
	
	$begin=$in_begin{$in};
	$end=$in_end{$in};
	
	if ($begin < $end){
		for($j=$begin; $j<$end+1; $j++){
			print O_V_FILE "pc3d01 I$i ( .CIN(wire_$in\[${j}\]), .PAD(net${net}));\n";
			$i +=1;
			$net +=1;	
		}
	}
	elsif ($begin > $end){
		for($j=$begin; $j>$end-1; $j--){
			print O_V_FILE "pc3d01 I$i ( .CIN(wire_$in\[${j}\]), .PAD(net${net}));\n";
			$i +=1;
			$net +=1;	
		}
	}
	else {
		print O_V_FILE "pc3d01 I$i ( .CIN(wire_$in), .PAD(net${net}));\n";
		$i +=1;
		$net +=1;	
	}
}


#------------creating out pads-------------
print O_V_FILE "\n";
foreach $out (sort keys %out_begin){
	
	$begin=$out_begin{$out};
	$end=$out_end{$out};
	
	if ($begin < $end){
		for($j=$begin; $j<$end+1; $j++){
# change goel print O_V_FILE "pt3o01 I$i ( .Y(wire_$out\[${j}\]), .PAD(net${net}));\n";
                        print O_V_FILE "pt3o01 I$i ( .PAD(net${net}), .I(wire_$out\[${j}\]));\n";
			$i +=1;
			$net +=1;	
		}
	}
	elsif ($begin > $end){
		for($j=$begin; $j>$end-1; $j--){
			print O_V_FILE "pt3o01 I$i ( .PAD(net${net}), .I(wire_$out\[${j}\]));\n";
			$i +=1;
			$net +=1;	
		}
	}
	else{
		print O_V_FILE "pt3o01 I$i ( .PAD(net${net}), .I(wire_$out));\n";
		$i +=1;
		$net +=1;	
	}
}


print O_V_FILE "\npfrelr Pcornerlr();\n";
print O_V_FILE "pfrelr Pcornerll();\n";
print O_V_FILE "pfrelr Pcornerur();\n";
print O_V_FILE "pfrelr Pcornerul();\n";

print O_V_FILE "\nendmodule\n\n";

close I_FILE;
open (I_FILE , "<$fileIn") or die "cannot open $fileIn\n";
while ($line = <I_FILE>) {
	print O_V_FILE "$line";
}




#--------------creating $fileOutIO file--------------------

my $north;
my $south;
my $west;
my $east;

$i--;
my $lowVal= int($i/4);
my $left = $i - $lowVal*4;

$north = $lowVal;
$south = $lowVal;
$west = $lowVal;
$east = $lowVal;

if ($left == 1){
	$north++;
}
elsif ($left == 2){
	$north++;
	$south++;
}
elsif ($left == 3){
	$north++;
	$south++;
	$west++;
}


print O_IO_FILE "######################################################\n";
print O_IO_FILE "#                                                    #\n";
print O_IO_FILE "#  Silicon Perspective, A Cadence Company            #\n";
print O_IO_FILE "#  FirstEncounter IO Assignment                      #\n";
print O_IO_FILE "#                                                    #\n";
print O_IO_FILE "######################################################\n\n";
print O_IO_FILE "Version: 2\n\n";


#north
print O_IO_FILE "Pad: PAD_G1   N\n";
print O_IO_FILE "Pad: PAD_G2   N\n";
print O_IO_FILE "Pad: PAD_G3   N\n";
print O_IO_FILE "Pad: PAD_I1   N\n";
print O_IO_FILE "Pad: PAD_I2   N\n";
print O_IO_FILE "Pad: PAD_I3   N\n";

for ($i=5; $i <= $north; $i++){
	print O_IO_FILE "Pad: I$i   N\n";	
}


#south 
for ($i=$north+1; $i <= $south+$north; $i++){
	print O_IO_FILE "Pad: I$i   S\n";	
}

#west
for ($i=$south+$north+1; $i <= $west+$south+$north; $i++){
	print O_IO_FILE "Pad: I$i   W\n";	
}



#east
for ($i=$west+$south+$north+1; $i <= $east+$west+$south+$north; $i++){
	print O_IO_FILE "Pad: I$i   E\n";	
}

print O_IO_FILE "Orient: R0\n";
print O_IO_FILE "Pad: Pcornerlr/I1 SW\n";
print O_IO_FILE "Orient: R90\n";
print O_IO_FILE "Pad: Pcornerur/I1 SE\n";
print O_IO_FILE "Orient: R180\n";
print O_IO_FILE "Pad: Pcornerul/I1 NE\n";
print O_IO_FILE "Orient: R270\n";
print O_IO_FILE "Pad: Pcornerll/I1 NW\n";


#--------------closing files--------------------

close O_V_FILE;
close O_IO_FILE;
close I_FILE;


