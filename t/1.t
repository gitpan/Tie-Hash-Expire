
use Test::More tests => 19;

BEGIN {
	warn "\n\n###################################################################\n";
	warn "##### Tests take some time because of testing expirations.    #####\n";
	warn "##### Tests may hang for up to 10 seconds with nothing wrong. #####\n";
	warn "###################################################################\n\n";

	use_ok('Tie::Hash::Expire');
};

my %test;
tie %test, 'Tie::Hash::Expire', {'expire_seconds' => 2};

### Test assignment (STORE), fetch (FETCH) and expiration.

$test{'fred'} = 'barney';
sleep 1;
is($test{fred}, 'barney',	'value storage and retrieval');
sleep 1;
is($test{fred},	undef,		'basic expiration');

### Test slicing

@test{'fred','lone ranger'} = ('barney','tonto');
is($test{'fred'}, 'barney',		'hash slice');
is($test{'lone ranger'}, 'tonto',	'hash slice 2');


### Test DELETE

delete $test{'fred'};
is($test{fred},	undef,			'delete');
is($test{'lone ranger'}, 'tonto',	'delete 2');


### Test CLEAR

%test = ();
is($test{'lone ranger'}, undef,	'clear');
is(scalar keys(%test),	0,	'clear 2');


### Test EXISTS, defined, etc.

%test = (
	true	=>	'Hello',
	false	=>	0,
	undefined	=>	undef,
);

ok($test{true},			'exists 1');
ok(defined($test{false}),	'exists 2');
ok(exists($test{undefined}),	'exists 3');
ok(!defined($test{undefined}),	'exists 4');


### Test FIRSTKEY and NEXTKEY and expiration while iterating

%test = (
	'one'	=>	1,
	'two'	=>	2,
	'three'	=>	3,
);

ok(eq_set([keys %test],	[qw/one two three/]),	'keys 1'); 
ok(eq_set([values %test],	[1,2,3,]),	'keys 2'); 

sleep 1;

$test{three} = 'three';
$test{four} = 4;

ok(eq_set([keys %test],	[qw/one two three four/]),	'keys 3'); 
ok(eq_set([values %test],	[1,2,'three',4,]),	'keys 4'); 

sleep 1;

ok(eq_set([keys %test],	[qw/three four/]),	'keys 5'); 
ok(eq_set([values %test],	['three',4,]),	'keys 6'); 



