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
my (%counts,%grand,%files);
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
      my $lines=0;
      { local $/="\n"; $lines++ while <$fh>; }
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
print "Physical source lines (including comments and blanks); tracked working-tree files only.\n";
print $vendor ? "Vendored paths and recognized generated filenames included.\n" :
   "Vendored paths and recognized generated filenames excluded (use --include-vendor to include).\n";
exit($missing ? 1 : 0);
PERL
