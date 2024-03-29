
#define	CHUNK	6000
void
wrbitmap(Bitmap *b, int miny, int maxy, byte *data)
{
	byte *buf;
	int dy, px;
	uint l, t, n;

	px = 1<<(3-b->ldepth);	
	
	if(b->r.min.x >= 0)
		l = (b->r.max.x+px-1)/px - b->r.min.x/px;
	else{	
		t = (-b->r.min.x)+px-1;
		t = (t/px)*px;
		l = (t+b->r.max.x+px-1)/px;
	}
	while(maxy > miny){
		dy = maxy - miny;
		if(dy*l > CHUNK)
			dy = CHUNK/l;
		n = dy*l;
		buf = bneed(11+n);
		buf[0] = 'w';
		BPSHORT(buf+1, b->id);
		BPLONG(buf+3, miny);
		BPLONG(buf+7, miny+dy);
		memmove(buf+11, data, n);
		data += n;
		miny += dy;
	}
}
