#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
. .modules
exec perl - "$@" $BUILD <<'PERL'
use strict;
use warnings;
my $vendor = 0;
if (@ARGV && $ARGV[0] eq '--include-vendor') {
   shift @ARGV;
   $vendor = 1;
}
die "Usage: ./countlines.sh [--include-vendor]\n" if grep /^-/, @ARGV;
my %ext = (
   c=>'C', h=>'C headers', cc=>'C++', cpp=>'C++', cxx=>'C++',
   hh=>'C++ headers', hpp=>'C++ headers', hxx=>'C++ headers',
   js=>'JavaScript', mjs=>'JavaScript', cjs=>'JavaScript', jsx=>'JavaScript',
   ts=>'TypeScript', tsx=>'TypeScript', pl=>'Perl', pm=>'Perl', t=>'Perl',
   py=>'Python', sh=>'Shell', bash=>'Shell', rrs=>'RustyScript',
   html=>'HTML', htm=>'HTML', css=>'CSS', scss=>'SCSS', sql=>'SQL',
   awk=>'Awk', lua=>'Lua', rs=>'Rust', go=>'Go', s=>'Assembly',
   asm=>'Assembly', mk=>'Make', cmake=>'CMake', php=>'PHP',
   ps1=>'PowerShell', bat=>'Batch',
);
sub language {
   my ($p)=@_;
   return 'Make' if $p =~ m{(?:^|/)(?:GNUmakefile|[Mm]akefile|debian/rules)$};
   return 'CMake' if $p =~ m{(?:^|/)CMakeLists\.txt$};
   return $ext{lc $1} if $p =~ /\.([^.\/]+)$/;
   return;
}
# Comment-only lines and blanks; mixed code/comment lines count as code.
# This lightweight scanner is an estimate, not a full language parser.
sub noncode {
   my ($line,$lang,$state)=@_;
   return 1 if $line =~ /^\s*$/;
   my $cstyle=$lang =~ /^(?:C(?:\+\+)?(?: headers)?|JavaScript|TypeScript|RustyScript|Rust|Go|PHP|CSS|SCSS|SQL)$/;
   my $hash=$lang =~ /^(?:Perl|Python|Shell|Make|CMake|Awk|RustyScript|PHP|PowerShell)$/;
   my $slash=$cstyle && $lang !~ /^(?:CSS|SQL)$/;
   my $dash=$lang =~ /^(?:SQL|Lua)$/;
   my $html=$lang eq 'HTML';
   if ($lang eq 'Perl') {
      if ($state eq 'POD') {
         $state='' if $line =~ /^=cut\b/;
         return 1;
      }
      if ($line =~ /^=(?:pod|head[1-6]|over|item|back|begin|end|for|encoding)\b/) {
         $state='POD'; return 1;
      }
   }
   return 1 if $line =~ /^\s*(?:REM(?:\s|$)|::)/i && $lang eq 'Batch';
   return 1 if $line =~ /^\s*[;#]/ && $lang eq 'Assembly';
   my $code=0;
   while (length $line) {
      if (length $state) {
         my $i=index($line,$state);
         return !$code if $i<0;
         substr($line,0,$i+length($state),'');
         $state=''; next;
      }
      $line =~ s/^\s+//;
      last unless length $line;
      if ($cstyle && $line =~ s{^/\*}{}) { $state='*/'; next; }
      if ($html && $line =~ s/^<!--//) { $state='-->'; next; }
      if ($lang eq 'PowerShell' && $line =~ s/^<#//) { $state='#>'; next; }
      if ($lang eq 'Lua' && $line =~ s/^--\[(=*)\[//) { $state=']'.$1.']'; next; }
      last if ($hash && $line =~ /^#/) || ($slash && $line =~ m{^//}) ||
              ($dash && $line =~ /^--/);
      $code=1;
      # Consume quoted strings as units, avoiding comment markers inside them.
      if ($line =~ s/^(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\x60(?:\\.|[^\x60\\])*\x60)//) { next; }
      # Skip ordinary code in chunks rather than scanning byte by byte.
      $line =~ s{^[^/"'#<\x60-]+}{} or substr($line,0,1,'');
   }
   return !$code;
}
my (%counts,%grand,%files,%noncode,%noncode_grand);
my $missing=0;
my @modules;
my %module_seen;
for my $module ('rrpk',@ARGV) {
   next if $module_seen{$module}++;
   my $dir=$module eq 'rrpk' ? '.' : "src/$module";
   unless (-e "$dir/.git") {
      warn "Missing checkout: $dir (run ./fetch-all.sh)\n";
      $missing=1; next;
   }
   push @modules,$module;
   $counts{$module}={};
   $files{$module}=0;
   open my $git,'-|','git','-C',$dir,'ls-files','-z' or die "git: $!";
   local $/="\0";
   my %seen;
   while (my $path=<$git>) {
      chomp $path;
      next if $seen{$path}++;
      next if $path =~ m{(?:^|/)(?:build|node_modules|__pycache__)(?:/|$)};
      next if !$vendor && $path =~ m{(?:^|/)(?:vendor|third_party|third-party|ext)(?:/|$)};
      next if !$vendor && $path =~ /(?:\.generated\.|\.min\.js$|\.min\.css$)/;
      my $lang=language($path) or next;
      my $file="$dir/$path";
      next unless -f $file && !-l $file && -T $file;
      open my $fh,'<:raw',$file or die "$file: $!";
      my ($lines,$nc,$state)=(0,0,'');
      { local $/="\n"; while (my $line=<$fh>) { $lines++; $nc++ if noncode($line,$lang,\$state); } }
      $noncode{$module}{$lang}+=$nc;
      $noncode_grand{$lang}+=$nc;
      close $fh or die "$file: $!";
      $counts{$module}{$lang}+=$lines;
      $grand{$lang}+=$lines;
      $files{$module}++;
   }
   close $git or die "git ls-files failed for $dir\n";
}
sub sum { my $n=0; $n+=$_ for @_; return $n; }
my @langs=sort { $grand{$b}<=>$grand{$a} || $a cmp $b } keys %grand;
my $width=12;
for (@modules) { $width=length($_) if length($_)>$width; }
printf "%-*s %12s",$width,'Language','TOTAL';
printf " %*s",$width,$_ for @modules;
print "\n";
for my $lang (@langs) {
   printf "%-*s %12d",$width,$lang,$grand{$lang};
   printf " %*d",$width,$counts{$_}{$lang}//0 for @modules;
   print "\n";
}
printf "%-*s %12d",$width,'TOTAL LINES',sum(values %grand);
printf " %*d",$width,sum(values %{$counts{$_}}) for @modules;
print "\n";
printf "%-*s %12d",$width,'FILES',sum(values %files);
printf " %*d",$width,$files{$_} for @modules;
print "\n";
sub percent { my ($n,$d)=@_; return $d ? sprintf('%.1f%%',100*$n/$d) : '-'; }
print "\nComment-only + blank lines (% of physical lines; approximate)\n";
printf "%-*s %12s",$width,'Language','TOTAL';
printf " %*s",$width,$_ for @modules;
print "\n";
for my $lang (@langs) {
   printf "%-*s %12s",$width,$lang,percent($noncode_grand{$lang},$grand{$lang});
   printf " %*s",$width,percent($noncode{$_}{$lang}//0,$counts{$_}{$lang}//0) for @modules;
   print "\n";
}
printf "%-*s %12s",$width,'TOTAL',percent(sum(values %noncode_grand),sum(values %grand));
printf " %*s",$width,percent(sum(values %{$noncode{$_}//{}}),sum(values %{$counts{$_}})) for @modules;
print "\n";
printf "Code-bearing lines: %d; comment-only/blank lines: %d\n",
   sum(values %grand)-sum(values %noncode_grand),sum(values %noncode_grand);
print "Physical source lines (including comments and blanks); tracked working-tree files only.\n";
print $vendor ? "Vendored paths and recognized generated filenames included.\n" :
   "Vendored paths and recognized generated filenames excluded (use --include-vendor to include).\n";
exit($missing ? 1 : 0);
PERL
