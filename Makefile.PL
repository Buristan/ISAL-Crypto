use ExtUtils::MakeMaker;
use Cwd qw(abs_path);
use Config;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Check nasm and yasm versions support
my $nasm_v = qx(nasm -v);
$nasm_v =~ s{\A.*version (\d+)\.(\d+)\.(\d+).*}{sprintf "%d.%02d%02d", $1, $2, $3}e;

# Yasm don't support avx512 now
# my $yasm_v = qx(yasm --version | head -n1);
# $yasm_v =~ s{\A.*yasm (\d+)\.(\d+)\.(\d+).*}{sprintf "%d.%02d%02d", $1, $2, $3}e;

if ($nasm_v < 2.13) {
	warn "nasm version >= 2.13.00 is required";
	exit 0;
}

my $autoreconf = qx(autoreconf --version);
unless ($autoreconf) {
	# TODO add not only reconf building
	warn "autotools required for building";
	exit 0;
}

sub MY::postamble {
q|
BENCH_FILES = bench/*/*.pl
BENCH_VERBOSE = 0

bench:
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-MTest::Harness" "-e" "undef *Test::Harness::Switches; test_harness($(BENCH_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(BENCH_FILES)

.PHONY: bench

readme:
	$(FULLPERLRUN) -MPod::Markdown -e 'Pod::Markdown->new->filter(@ARGV)' lib/ISAL/Crypto.pm > README.md

.PHONY: readme
|
}

my $preop = 'make readme';

WriteMakefile(
	NAME         => 'ISAL::Crypto',
	VERSION_FROM => 'lib/ISAL/Crypto.pm',
	PREREQ_PM    => {},
	ABSTRACT_FROM  => 'lib/ISAL/Crypto.pm', # retrieve abstract from module
	AUTHOR  => 'Sergey Kaplun <burii@cpan.org>',
	LICENSE => 'BSD 3-Clause',
	LIBS      => [],
	DEFINE    => (-d ".git" ? '-g -ggdb' : ''),
	CONFIGURE => sub {
		my %opt;
		for my $opt (split /:+/, $ENV{PERL_ISAL_OPT}) {
			my ($k,$v) = split /=/, $opt;
			$opt{$k} = $v;
		}
		
		my $extra = $Config{sitearch};
		
		$extra =~ s/$Config{prefix}/$opt{PREFIX}/ if exists $opt{PREFIX};
		
		my $installsitearch = abs_path "./";
		for my $d ($extra, @INC) {
			if (-e "$d/ISAL/Crypto/include/isa-l_crypto.h") {
				$installsitearch = abs_path $d;
				last;
			}
		}
		$opt{CFLAGS} //= "-O2 -fPIC". (-d ".git" ? " -g " : "");
		
		my $libdir = "$installsitearch/ISAL/Crypto/lib/";
		$opt{MAKEFLAGS} //= ""; # compatibility with solaris dmake
		# TODO not only autotools supports - require to reworking isa-l_crypto/Makefile.unx
		$opt{USEAUTOTOOLS} = 1;
		my $installation = $opt{USEAUTOTOOLS} ?
			qq|
				./autogen.sh &&
				CFLAGS="$opt{CFLAGS}" ./configure --prefix=$installsitearch/ISAL/Crypto &&
				make $opt{MAKEFLAGS} &&
				# make test; # ENV_sm3 supported only in the newest libssl
				make install &&
				make clean;
			|
			: qq|
				make $opt{MAKEFLAGS} -f Makefile.unx &&
				PREFIX=$installsitearch/ISAL/Crypto make -f Makefile.unx install &&
				make clean;
			|;
		my $f = system qq|
			cd ./isa-l_crypto/ &&
			$installation
		|;
		
		die "Failed to build sources!" if $f;
		
		return {
			INC => "-I. -I$installsitearch/ISAL/Crypto -I$installsitearch",
			LDFROM => "Crypto.o",
			LIBS => "-L$libdir -lisal_crypto",
			CCFLAGS => " $opt{CFLAGS} -Wall"
			           ." -I$installsitearch/ISAL/Crypto/include",
		}
	},
	PL_FILES => {
		'multiply_tests.pl'  => [qw(MD5 SHA1 SHA256 SHA512)],
		'multiply_benchs.pl' => [qw(MD5 SHA1 SHA256 SHA512)],
	},
	test   => {TESTS => 't/*/*.t'},
	dist   => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', PREOP => $preop },
	TEST_REQUIRES => {
		'Net::SSLeay' => 1.46,
	},
	OBJECT => "Crypto.o "
);
