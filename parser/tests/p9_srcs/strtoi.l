
#define LONG_MAX	2147483647
#define LONG_MIN	-2147483648

int
strtoi(byte *nptr, byte **endptr, int base)
{
	byte *p;
	int n, nn;
	int c, ovfl, v, neg, ndig;

	p = nptr;
	neg = 0;
	n = 0;
	ndig = 0;
	ovfl = 0;

	/*
	 * White space
	 */
	for(;;p++){
		switch(*p){
		case ' ':
		case '\t':
		case '\n':
		case '\f':
		case '\r':
		case '\v':
			continue;
		}
		break;
	}

	/*
	 * Sign
	 */
	if(*p=='-' || *p=='+')
		if(*p++ == '-')
			neg = 1;

	/*
	 * Base
	 */
	if(base==0){
		if(*p != '0')
			base = 10;
		else{
			base = 8;
			if(p[1]=='x' || p[1]=='X'){
				p += 2;
				base = 16;
			}
		}
	}else if(base==16 && *p=='0'){
		if(p[1]=='x' || p[1]=='X')
			p += 2;
	}else if(base<0 || 36<base)
		goto Return;

	/*
	 * Non-empty sequence of digits
	 */
	for(;; ndig++){
		c = *p;
		v = base;
		if('0'<=c && c<='9')
			v = c - '0';
		else if('a'<=c && c<='z')
			v = c - 'a' + 10;
		else if('A'<=c && c<='Z')
			v = c - 'A' + 10;
		if(v >= base)
			break;
		nn = n*base + v;
		if(nn < n)
			ovfl = 1;
		n = nn;
		p++;
	}

    Return:
	if(ndig == 0)
		p = nptr;
	if(endptr)
		*endptr = p;
	if(ovfl){
		if(neg)
			return LONG_MIN;
		return LONG_MAX;
	}
	if(neg)
		return -n;
	return n;
}
