
float
pow(float x, float y) 
{
	float xy, y1, ye;
	int i, ex, ey, flip;

	if(y == 0.0)
		return 1.0;

	flip = 0;
	if(y < 0.){
		y = -y;
		flip = 1;
	}
	y1 = modf(y, &ye);
	if(y1 != 0.0){
		if(x <= 0.)
			goto zreturn;
		if(y1 > 0.5) {
			y1 -= 1.;
			ye += 1.;
		}
		xy = exp(y1 * log(x));
	}else
		xy = 1.0;
	if(ye > 0x7FFFFFFF){	
		if(x <= 0.){
 zreturn:
			if(x==0. && !flip)
				return 0.;
			return NaN();
		}
		if(flip){
			if(y == .5)
				return 1./sqrt(x);
			y = -y;
		}else if(y == .5)
			return sqrt(x);
		return exp(y * log(x));
	}
	x = frexp(x, &ex);
	ey = 0;
	i = ye;
	if(i)
		for(;;){
			if(i & 1){
				xy *= x;
				ey += ex;
			}
			i >>= 1;
			if(i == 0)
				break;
			x *= x;
			ex <<= 1;
			if(x < .5){
				x += x;
				ex -= 1;
			}
		}
	if(flip){
		xy = 1. / xy;
		ey = -ey;
	}
	return ldexp(xy, ey);
}
