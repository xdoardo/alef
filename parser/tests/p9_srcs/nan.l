
enum
{
	NANEXP	= (2047<<20),
	NANMASK	= (2047<<20),
	NANSIGN	= (1<<31),
};

union Cheat
{
	float	d;
	int	x[2];
};

float
NaN(void)
{
	Cheat a;

	a.x[0] = NANEXP;
	a.x[1] = 1;
	return a.d;
}

int
isNaN(float d)
{
	Cheat a;

	a.d = d;
	if((a.x[0] & NANMASK) != NANEXP)
		return 0;
	return !isInf(d, 0);
}

float
Inf(int sign)
{
	Cheat a;

	a.x[0] = NANEXP;
	a.x[1] = 0;
	if(sign < 0)
		a.x[0] |= NANSIGN;
	return a.d;
}

int
isInf(float d, int sign)
{
	Cheat a;

	a.d = d;
	if(a.x[1] != 0)
		return 0;
	if(a.x[0] == NANEXP)
		return sign >= 0;
	if(a.x[0] == (NANEXP|NANSIGN))
		return sign <= 0;
	return 0;
}
