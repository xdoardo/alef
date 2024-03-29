
Bitmap*
balloc(Rectangle r, int ldepth)
{
	int id;
	Bitmap *b;
	byte *buf, xbuf[3];

	bneed(0);		
	buf = bneed(18);
	buf[0] = 'a';
	buf[1] = ldepth;

	BPLONG(buf+2, r.min.x);
	BPLONG(buf+6, r.min.y);
	BPLONG(buf+10, r.max.x);
	BPLONG(buf+14, r.max.y);

	if(!bwrite())
		return nil;	

	if(read(bitbltfd, xbuf, 3) != 3 || xbuf[0]!='A')
		berror("balloc read");

	id = xbuf[1] | (xbuf[2]<<8);
	b = malloc(sizeof(Bitmap));
	if(b == nil) {
		buf[0] = 'f';
		write(bitbltfd, xbuf, 3);
		berror("balloc malloc");
	}

	b->ldepth = ldepth;
	b->r = r;
	b->clipr = r;
	b->id = id;
	b->cache = nil;
	return b;
}

void
bfree(Bitmap *b)
{
	byte *buf;

	buf = bneed(3);
	buf[0] = 'f';
	buf[1] = b->id;
	buf[2] = b->id>>8;
	free(b);
	bneed(0);	
}
