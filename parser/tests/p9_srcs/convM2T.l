
#define	CHAR(x)		f->x = *p++
#define	SHORT(x)	f->x = (p[0] | (p[1]<<8)); p += 2
#define	VLONG(q)	q = (p[0] | (p[1]<<8) | (p[2]<<16) | (p[3]<<24)); p += 4
#define	LONG(x)		VLONG(f->x)
#define	STRING(x,n)	memmove(f->x, p, n); p += n

void
convM2T(byte *ap, Ticket *f, byte *key)
{
	byte *p;

	if(key)
		decrypt(key, ap, TICKETLEN);
	p = ap;
	CHAR(num);
	STRING(chal, CHALLEN);
	STRING(cuid, NAMELEN);
	f->cuid[NAMELEN-1] = 0;
	STRING(suid, NAMELEN);
	f->suid[NAMELEN-1] = 0;
	STRING(key, DESKEYLEN);
	if(p);
}
