
/*
 * sinh(arg) returns the hyperbolic sine of its floating-
 * point argument.
 *
 * The exponential function is called for arguments
 * greater in magnitude than 0.5.
 *
 * A series is used for arguments smaller in magnitude than 0.5.
 * The coefficients are #2029 from Hart & Cheney. (20.36D)
 *
 * cosh(arg) is computed from the exponential function for
 * all arguments.
 */

intern	float	p0  = -0.6307673640497716991184787251e+6;
intern	float	p1  = -0.8991272022039509355398013511e+5;
intern	float	p2  = -0.2894211355989563807284660366e+4;
intern	float	p3  = -0.2630563213397497062819489e+2;
intern	float	q0  = -0.6307673640497716991212077277e+6;
intern	float	q1   = 0.1521517378790019070696485176e+5;
intern	float	q2  = -0.173678953558233699533450911e+3;

float
sinh(float arg)
{
	float temp, argsq;
	int sign;

	sign = 0;
	if(arg < 0) {
		arg = -arg;
		sign++;
	}
	if(arg > 21) {
		temp = exp(arg)/2;
		goto out;
	}
	if(arg > 0.5) {
		temp = (exp(arg) - exp(-arg))/2;
		goto out;
	}
	argsq = arg*arg;
	temp = (((p3*argsq+p2)*argsq+p1)*argsq+p0)*arg;
	temp /= (((argsq+q2)*argsq+q1)*argsq+q0);
out:
	if(sign)
		temp = -temp;
	return temp;
}

float
cosh(float arg)
{
	if(arg < 0)
		arg = - arg;
	if(arg > 21)
		return exp(arg)/2;
	return (exp(arg) + exp(-arg))/2;
}
