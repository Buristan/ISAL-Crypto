#!/usr/bin/perl

use File::Copy 'copy';
use Errno 'EEXIST';
use FindBin;

my @ALGOS = @ARGV;

my $dir = "$FindBin::Bin/mb_bench_templates";
opendir(my $dh, $dir) || die "Can't opendir $dir: $!";
my @test_files = grep /\A[^.]/, readdir $dh;
for my $t_file (@test_files) {
	for my $alg (@ALGOS) {
		mkdir "$dir/../bench/" or $!{EEXIST}
			or die "Can't create $dir/../bench/: $!";
		mkdir "$dir/../bench/$alg" or $!{EEXIST}
			or die "Can't create $dir/../bench/$alg: $!";
		
		copy("$dir/$t_file", "$dir/../bench/$alg/$t_file")
			or die "Failed to copy file: $dir/$t_file to".
				"$dir/../bench/$alg/$t_file: $!";
	}
}
closedir($dh) or warn "Can't closedir $dir: $!"
