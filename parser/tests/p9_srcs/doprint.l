
int	printcol;


enum
{
	SIZE	= 1024,
	IDIGIT	= 30,
	MAXCONV	= 40,
	FDIGIT	= 30,
	FDEFLT	= 6,
	NONE	= -1000,

	FPLUS	= (1<<0),
	FMINUS	= (1<<1),
	FSHARP	= (1<<2),
	FLONG	= (1<<3),
	FSHORT	= (1<<4),
	FUNSIGN	= (1<<5),
	FVLONG	= (1<<6),

	PTR	= sizeof(byte*),
	SHORT	= sizeof(int),
	INT	= sizeof(int),
	LONG	= sizeof(int),
	FLOAT	= sizeof(float),
};

intern	byte	fmtindex[128];
intern	byte	sptest[128];

intern	int	noconv(Printspec*);
intern	int	flags(Printspec*);
intern	int	cconv(Printspec*);
intern	int	sconv(Printspec*);
intern	int	percent(Printspec*);
intern	int	rconv(Printspec*);
intern	int	Sconv(Printspec*);
	int	numbconv(Printspec*);
	int	fltconv(Printspec*);

intern	int	convcount;
intern	int	(*fmtconv[MAXCONV])(Printspec*);

Lock	printlock;

intern	void
initfmt(void)
{
	fmtconv[0] = noconv;

	fmtconv[1] = flags;
	fmtindex['+'] = 1;
	fmtindex['-'] = 1;
	fmtindex['#'] = 1;
	fmtindex['h'] = 1;
	fmtindex['l'] = 1;
	fmtindex['u'] = 1;

	fmtconv[2] = numbconv;
	fmtindex['d'] = 2;
	fmtindex['o'] = 2;
	fmtindex['x'] = 2;
	fmtindex['X'] = 2;

	fmtconv[3] = fltconv;
	fmtindex['e'] = 3;
	fmtindex['f'] = 3;
	fmtindex['g'] = 3;
	fmtindex['E'] = 3;
	fmtindex['G'] = 3;

	fmtconv[4] = cconv;
	fmtindex['c'] = 4;
	fmtindex['C'] = 4;

	fmtconv[5] = sconv;
	fmtindex['s'] = 5;

	fmtconv[6] = percent;
	fmtindex['%'] = 6;

	fmtconv[7] = rconv;
	fmtindex['r'] = 7;

	fmtconv[8] = Sconv;
	fmtindex['S'] = 8;

	convcount = 9;

	memset(sptest, 1, sizeof(sptest));
	sptest[0] = 0;
	sptest['\t'] = 0;
	sptest['\n'] = 0;
	sptest['%'] = 0;
}

int
fmtinstall(int c, int (*f)(Printspec*))
{
	printlock.lock();
	if(convcount == 0)
		initfmt();

	c &= 0xff;
	if(convcount >= MAXCONV) {
		printlock.unlock();
		return -1;
	}

	fmtindex[c] = convcount++;
	fmtconv[fmtindex[c]] = f;
	printlock.unlock();
	return 0;
}

byte*
doprint(byte *s, byte *es, byte *fmt, void *argp)
{
	Printspec p;
	int f1, f2, f3, c, n;

	if(convcount == 0)
		initfmt();

	p.out = s;
	p.eout = es;

loop:
	/*
	 * here to the next comment --
	 * a speed hack to quickly skip
	 * normal characters.
	 */
	f2 = p.eout - p.out;
	for(f1=0; f1<f2; f1++) {
		c = fmt[f1];
		if(!sptest[c&0177])
			break;
		p.out[f1] = c;
	}

	fmt += f1;
	p.out += f1;
	printcol += f1;		

	c = *fmt++;
	if(c != '%') {
		if(c == 0) {
			if(p.out >= p.eout)
				p.out = p.eout-1;
			if(p.out < p.eout)
				*p.out = 0;
			return p.out;
		}
		if(p.out < p.eout)
			*p.out++ = c;
		printcol++;
		if(c == '\n')
			printcol = 0;
		else
		if(c == '\t')
			printcol = (printcol+7) & ~7;
		goto loop;
	}
	f1 = NONE;
	f2 = NONE;
	f3 = 0;

	/*
	 * read one of the following
	 *	1. number, => f1, f2 in order.
	 *	2. '*' same as number (from args)
	 *	3. '.' ignored (separates numbers)
	 *	4. flag => f3
	 *	5. verb and terminate
	 */
l0:
	c = *fmt++;

l1:
	if(c == 0) {
		fmt--;
		goto loop;
	}
	if(c == '.') {
		if(f1 == NONE)
			f1 = 0;
		f2 = 0;
		goto l0;
	}
	if((c >= '1' && c <= '9') ||
	   (c == '0' && f1 != NONE)) {	
		n = 0;
		while(c >= '0' && c <= '9') {
			n = n*10 + c-'0';
			c = *fmt++;
		}
		if(f1 == NONE)
			f1 = n;
		else
			f2 = n;
		goto l1;
	}
	if(c == '*') {
		n = *(int*)argp;
		argp = (byte*)argp + INT;
		if(f1 == NONE)
			f1 = n;
		else
			f2 = n;
		goto l0;
	}

	c &= 0177;
	p = (Printspec)(argp, f1, f2, f3, c, p.out, p.eout);
	n = fmtindex[c];
	if(n < 0 || n >= convcount)
		n = 0;
	n = (*fmtconv[n])(&p);
	if(n < 0) {
		f3 |= -n;
		goto l0;
	}
	argp = (byte*)argp + n;
	goto loop;

	return nil;
}

int
numbconv(Printspec *p)
{
	sint h;
	int v;
	byte s[IDIGIT];
	int i, f, n, r, b, ucase;

	ucase = 0;
	b = p->chr;
	switch(p->chr) {
	case 'u':
		p->f3 |= FUNSIGN;
	case 'd':
		b = 10;
		break;

	case 'o':
		b = 8;
		break;

	case 'X':
		ucase = 1;
	case 'x':
		b = 16;
		break;
	}

	f = 0;
	switch(p->f3 & (FVLONG|FLONG|FSHORT|FUNSIGN)) {
	case FLONG:
		v = *(int*)p->o;
		r = LONG;
		break;

	case FUNSIGN|FLONG:
		v = *(uint*)p->o;
		r = LONG;
		break;

	case FSHORT:
		h = *(int*)p->o;
		v = h;
		r = SHORT;
		break;

	case FUNSIGN|FSHORT:
		h = *(int*)p->o;
		v = (usint)h;
		r = SHORT;
		break;

	default:
		v = *(int*)p->o;
		r = INT;
		break;

	case FUNSIGN:
		v = *(uint*)p->o;
		r = INT;
		break;
	}
	if(!(p->f3 & FUNSIGN) && v < 0) {
		v = -v;
		f = 1;
	}
	s[IDIGIT-1] = 0;
	for(i = IDIGIT-2;; i--) {
		n = (uint)v % b;
		n += '0';
		if(n > '9') {
			n += 'a' - ('9'+1);
			if(ucase)
				n += 'A'-'a';
		}
		s[i] = n;
		if(i < 2)
			break;
		v = (uint)v / b;
		if(p->f2 != NONE && i >= IDIGIT-p->f2)
			continue;
		if(v <= 0)
			break;
	}
	if(p->f3 & FSHARP)
	if(s[i] != '0') {
		if(b == 8)
			s[--i] = '0';
		else
		if(b == 16) {
			if(ucase)
				s[--i] = 'X';
			else
				s[--i] = 'x';
			s[--i] = '0';
		}
	}
	if(f)
		s[--i] = '-';

	p->f2 = NONE;
	strconv(p, s+i);
	return r;
}

void
strconv(Printspec *p, byte *s)
{
	int n, c;

	if(p->f1 != NONE && p->f3 & FMINUS)
		p->f1 = -p->f1;
	n = strlen(s);
	if(p->f1 != NONE && p->f1 >= 0)
		while(n < p->f1) {
			if(p->out < p->eout)
				*p->out++ = ' ';
			printcol++;
			n++;
		}

	for(; c = *s++;)
		if(p->f2 == NONE || p->f2 > 0) {
			if(p->out < p->eout)
				*p->out++ = c;
			printcol++;
			if(c == '\n')
				printcol = 0;
			else
			if(c == '\t')
				printcol = (printcol+7) & ~7;
			if(p->f2 != NONE)
				p->f2--;
		}
	if(p->f1 != NONE && p->f1 < 0) {
		p->f1 = -p->f1;
		while(n < p->f1) {
			if(p->out < p->eout)
				*p->out++ = ' ';
			printcol++;
			n++;
		}
	}
}

intern	int
noconv(Printspec *p)
{
	byte s[4];

	if(convcount == 0) {
		initfmt();
		return (*fmtconv[fmtindex[p->chr]])(p);
	}
	s[0] = '*';
	s[1] = p->chr;
	s[2] = '*';
	s[3] = 0;
	p->f1 = 0;
	p->f2 = NONE;
	strconv(p, s);
	return 0;
}

intern	int
cconv(Printspec *p)
{
	int i;
	Rune r;
	byte s[4];

	switch(p->chr) {
	case 'c':
		s[0] = *(int*)p->o;
		s[1] = 0;
		break;
	case 'C':
		r = *(int*)p->o;
		i = runetochar(s, &r);
		s[i] = 0;
		break;
	}
	p->f2 = NONE;
	strconv(p, s);
	return INT;
}

intern	int
rconv(Printspec *p)
{
	byte buf[ERRLEN];

	buf[0] = 0;
	errstr(buf);
	strconv(p, buf);
	return 0;
}

intern	int
sconv(Printspec *p)
{
	strconv(p, *(byte**)p->o);
	return PTR;
}

intern	int
Sconv(Printspec *p)
{
	int n, c, i;
	Rune rune, *s;

	s = *(Rune**)p->o;
	if(p->f3 & FMINUS)
		p->f1 = -p->f1;
	n = 0;
	if(p->f1 != NONE && p->f1 >= 0) {
		for(; s[n]; n++)
			;
		while(n < p->f1) {
			if(p->out < p->eout)
				*p->out++ = ' ';
			printcol++;
			n++;
		}
	}
	for(;;) {
		c = *s++;
		if(c == 0)
			break;
		n++;
		if(p->f2 == NONE || p->f2 > 0) {
			if(p->out < p->eout)
				if(c >= Runeself) {
					rune = c;
					i = runetochar(p->out, &rune);
					p->out += i;
				}
				else
					*p->out++ = c;
			if(p->f2 != NONE)
				p->f2--;
			switch(c) {
			default:
				printcol++;
				break;
			case '\n':
				printcol = 0;
				break;
			case '\t':
				printcol = (printcol+8) & ~7;
				break;
			}
		}
	}
	if(p->f1 != NONE && p->f1 < 0) {
		p->f1 = -p->f1;
		while(n < p->f1) {
			if(p->out < p->eout)
				*p->out++ = ' ';
			printcol++;
			n++;
		}
	}
	return PTR;
}

intern	int
percent(Printspec *p)
{

	if(p->out < p->eout)
		*p->out++ = '%';
	return 0;
}

intern	int
flags(Printspec *p)
{

	switch(p->chr) {
	case '+':
		return -FPLUS;

	case '-':
		return -FMINUS;

	case '#':
		return -FSHARP;

	case 'h':
		return -FSHORT;

	case 'l':
		if(p->f3 & FLONG)
			return -FVLONG;
		return -FLONG;

	case 'u':
		return -FUNSIGN;
	}
	return 0;
}

int
fltconv(Printspec *p)
{
	float f, g, h;
	int e, d, i, n, s;
	int c1, c2, c3, ucase;
	byte s1[FDIGIT+10], s2[FDIGIT+10];

	f = *(float*)p->o;
	if(isNaN(f)){
		p->f2 = NONE;
		strconv(p, "NaN");
		return FLOAT;
	}
	if(isInf(f, 1)){
		p->f2 = NONE;
		strconv(p, "+Inf");
		return FLOAT;
	}
	if(isInf(f, -1)){
		p->f2 = NONE;
		strconv(p, "-Inf");
		return FLOAT;
	}
	s = 0;
	if(f < 0) {
		f = -f;
		s++;
	}
	ucase = 0;
	if(p->chr >= 'A' && p->chr <= 'Z') {
		ucase = 1;
		p->chr += 'a'-'A';
	}

loop:
	e = 0;
	if(f != 0) {
		frexp(f, &e);
		e = e * .30103;
		d = e/2;
		h = f * pow10(-d);		
		g = h * pow10(d-e);
		while(g < 1) {
			e--;
			g = h * pow10(d-e);
		}
		while(g >= 10) {
			e++;
			g = h * pow10(d-e);
		}
	}
	if(p->f2 == NONE)
		p->f2 = FDEFLT;
	if(p->chr == 'g' && p->f2 > 0)
		p->f2--;
	if(p->f2 > FDIGIT)
		p->f2 = FDIGIT;
	/*
	 * n is number of digits to convert
	 * 1 before, f2 after, 1 extra for rounding
	 */
	n = p->f2 + 2;
	if(p->chr == 'f') {
		/*
		 * e+1 before, f2 after, 1 extra
		 */
		n += e;
		if(n <= 0)
			n = 1;
	}
	if(n >= FDIGIT+2) {
		if(p->chr == 'e')
			p->f2 = -1;
		p->chr = 'e';
		goto loop;
	}
	/*
	 * convert n digits
	 */
	g = f;
	if(e < 0)
		g *= pow10(-e-1);
	for(i=0; i<n; i++) {
		d = e-i;
		if(d >= 0) {
			h = pow10(d);
			d = floor(g/h);
			g -= d * h;
		} else {
			g *= 10;
			d = floor(g);
			g -= d;
		}
		s1[i+1] = d + '0';
	}
	/*
	 * round by adding .5 into extra digit
	 */
	d = 5;
	for(i=n-1; i>=0; i--) {
		s1[i+1] += d;
		d = 0;
		if(s1[i+1] > '9') {
			s1[i+1] -= 10;
			d++;
		}
	}
	i = 1;
	if(d) {
		s1[0] = '1';
		e++;
		i = 0;
	}
	/*
	 * copy into final place
	 * c1 digits of leading '0'
	 * c2 digits from conversion
	 * c3 digits after '.'
	 */
	d = 0;
	if(s)
		s2[d++] = '-';
	else
	if(p->f3 & FPLUS)
		s2[d++] = '+';
	c1 = 0;
	c2 = p->f2 + 1;
	c3 = p->f2;
	if(p->chr == 'g')
	if(e >= -5 && e <= p->f2) {
		c1 = -e - 1;
		if(c1 < 0)
			c1 = 0;
		c3 = p->f2 - e;
		p->chr = 'h';
	}
	if(p->chr == 'f') {
		c1 = -e;
		if(c1 < 0)
			c1 = 0;
		if(c1 > p->f2)
			c1 = c2;
		c2 += e;
		if(c2 < 0)
			c2 = 0;
	}
	while(c1 > 0) {
		if(c1+c2 == c3)
			s2[d++] = '.';
		s2[d++] = '0';
		c1--;
	}
	while(c2 > 0) {
		if(c1+c2 == c3)
			s2[d++] = '.';
		s2[d++] = s1[i++];
		c2--;
	}

	/*
	 * strip trailing '0' on g conv
	 */
	if(p->f3 & FSHARP) {
		if(c1+c2 == c3)
			s2[d++] = '.';
	} else
	if(p->chr == 'g' || p->chr == 'h') {
		for(n=d-1; n>=0; n--)
			if(s2[n] != '0')
				break;
		for(i=n; i>=0; i--)
			if(s2[i] == '.') {
				d = n;
				if(i != n)
					d++;
				break;
			}
	}
	if(p->chr == 'e' || p->chr == 'g') {
		if(ucase)
			s2[d++] = 'E';
		else
			s2[d++] = 'e';
		c1 = e;
		if(c1 < 0) {
			s2[d++] = '-';
			c1 = -c1;
		} else
			s2[d++] = '+';
		if(c1 >= 100) {
			s2[d++] = c1/100 + '0';
			c1 = c1%100;
		}
		s2[d++] = c1/10 + '0';
		s2[d++] = c1%10 + '0';
	}
	s2[d] = 0;
	p->f2 = NONE;
	strconv(p, s2);
	return FLOAT;
}
