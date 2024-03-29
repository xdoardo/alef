
#define	SLOP	25

void
_fraddbox(Frame *f, int bn, int n)	/* add n boxes after bn, shift the rest up,
				 * box[bn+n]==box[bn] */
{
	int i;

	if(bn > f->nbox)
		berror("_fraddbox");
	if(f->nbox+n > f->nalloc)
		_frgrowbox(f, n+SLOP);
	for(i=f->nbox; --i>=bn; )
		f->box[i+n] = f->box[i];
	f->nbox+=n;
}

void
_frclosebox(Frame *f, int n0, int n1)	
{
	int i;

	if(n0>=f->nbox || n1>=f->nbox || n1<n0)
		berror("_frclosebox");
	n1++;
	for(i=n1; i<f->nbox; i++)
		f->box[i-(n1-n0)] = f->box[i];
	f->nbox -= n1-n0;
}

void
_frdelbox(Frame *f, int n0, int n1)	
{
	if(n0>=f->nbox || n1>=f->nbox || n1<n0)
		berror("_frdelbox");
	_frfreebox(f, n0, n1);
	_frclosebox(f, n0, n1);
}

void
_frfreebox(Frame *f, int n0, int n1)	
{
	int i;

	if(n1<n0)
		return;
	if(n0>=f->nbox || n1>=f->nbox)
		berror("_frfreebox");
	n1++;
	for(i=n0; i<n1; i++)
		if(f->box[i].nrune >= 0)
			free(f->box[i].ptr);
}

void
_frgrowbox(Frame *f, int delta)
{
	f->nalloc += delta;
	f->box = realloc(f->box, f->nalloc*sizeof(Frbox));
	if(f->box == nil)
		berror("_frgrowbox");
}

intern
void
dupbox(Frame *f, int bn)
{
	byte *p;

	if(f->box[bn].nrune < 0)
		berror("dupbox");
	_fraddbox(f, bn, 1);
	if(f->box[bn].nrune >= 0){
		p = _frallocstr(NBYTE(&f->box[bn])+1);
		strcpy((byte*)p, (byte*)f->box[bn].ptr);
		f->box[bn+1].ptr = p;
	}
}

intern
byte*
runeindex(byte *p, int n)
{
	int i, w;
	Rune rune;

	for(i=0; i<n; i++) {
		if(*p < Runeself)
			w = 1;
		else
			w = chartorune(&rune, (byte*)p);
		p += w;
	}
	return p;
}

intern
void
truncatebox(Frame *f, Frbox *b, int n)	
{
	if(b->nrune<0 || b->nrune<n)
		berror("truncatebox");
	b->nrune -= n;
	runeindex(b->ptr, b->nrune)[0] = 0;
	b->wid = strwidth(f->font, (byte *)b->ptr);
}

intern
void
chopbox(Frame *f, Frbox *b, int n)	
{
	if(b->nrune<0 || b->nrune<n)
		berror("chopbox");
	strcpy((byte*)b->ptr, (byte*)runeindex(b->ptr, n));
	b->nrune -= n;
	b->wid = strwidth(f->font, (byte *)b->ptr);
}

void
_frsplitbox(Frame *f, int bn, int n)
{
	dupbox(f, bn);
	truncatebox(f, &f->box[bn], f->box[bn].nrune-n);
	chopbox(f, &f->box[bn+1], n);
}

void
_frmergebox(Frame *f, int bn)		
{
	Frbox *b;

	b = &f->box[bn];
	_frinsure(f, bn, NBYTE(&b[0])+NBYTE(&b[1])+1);
	strcpy((byte*)runeindex(b[0].ptr, b[0].nrune), (byte*)b[1].ptr);
	b[0].wid += b[1].wid;
	b[0].nrune += b[1].nrune;
	_frdelbox(f, bn+1, bn+1);
}

int
_frfindbox(Frame *f, int bn, uint p, uint q)	
{
	Frbox *b;
	uint nrune;

	for(b = &f->box[bn]; bn < f->nbox; bn++) {
		nrune = 1;
		if(b->nrune >= 0)
			nrune = b->nrune;
		if(p+nrune > q)
			break; 
		p += nrune;
		b++;
	}

	if(p != q)
		_frsplitbox(f, bn++, (int)(q-p));
	return bn;
}
