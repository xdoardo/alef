
#define	CHAR(x)		*p++ = f->x
#define	SHORT(x)	p[0] = f->x; p[1] = f->x>>8; p += 2
#define	VLONG(q)	p[0] = (q); p[1] = (q)>>8; p[2] = (q)>>16; p[3] = (q)>>24; p += 4
#define	LONG(x)		VLONG(f->x)
#define	STRING(x,n)	memmove(p, f->x, n); p += n

int
convPR2M(Passwordreq *f, byte *ap, byte *key)
{
	int n;
	byte *p;

	p = (byte*)ap;
	CHAR(num);
	STRING(old, NAMELEN);
	STRING(new, NAMELEN);
	n = p - (byte*)ap;
	if(key)
		encrypt(key, ap, n);
	return n;
}

