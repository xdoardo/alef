/*
 * floor and ceil-- greatest integer <= arg
 * (resp least >=)
 */

float
floor(float d)
{
	float fract;

	if(d < 0) {
		fract = modf(-d, &d);
		if(fract != 0.0)
			d += 1;
		d = -d;
	} else
		modf(d, &d);
	return d;
}

float
ceil(float d)
{
	return -floor(-d);
}
