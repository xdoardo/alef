
intern int	resize(Font*, int, int);
intern int	freeup(Font*);

#define	PJW	0	

int
cachechars(Font *f, byte **s, usint *cp, int max, int *wp)
{
	int i, th, sh, h, ld, w, wid, nc;
	byte *sp;
	Rune r, vr;
	uint a;
	Cacheinfo *c, *tc, *ec;

	sp = *s;
	wid = 0;
	for(i=0; *sp && i<max; sp+=w){
		r = *(byte*)sp;
		if(r < Runeself)
			w = 1;
		else{
			w = chartorune(&vr, sp);
			r = vr;
		}

		sh = (17 * (uint)r) & (f->ncache-NFLOOK-1);
		c = &f->cache[sh];
		ec = c+NFLOOK;
		h = sh;
		while(c < ec){
			if(c->value==r && c->age)
				goto Found;
			c++;
			h++;
		}
	
		/*
		 * Not found; toss out oldest entry
		 */
		a = ~0;
		th = sh;
		tc = &f->cache[th];
		while(tc < ec){
			if(tc->age < a){
				a = tc->age;
				h = th;
				c = tc;
			}
			tc++;
			th++;
		}

		if(a && (f->age-a)<500){	
			nc = 2*(f->ncache-NFLOOK) + NFLOOK;
			if(nc <= MAXFCACHE){
				if(i == 0)
					resize(f, f->width, nc);
				
				break;
			}
		}

		if(c->age == f->age)	
			break;

		ld = loadchar(f, r, c, h, i);
		if(ld <= 0){
			if(ld == 0)
				continue;
			break;
		}
		c = &f->cache[h];	
	
	    Found:
		wid += c->width;
		c->age = f->age;
		cp[i] = h;
		i++;
	}
	*s = sp;
	*wp = wid;
	return i;
}

int
charwidth(Font *f, Rune r)
{
	byte buf[UTFmax+1];
	byte *p;
	usint c;
	int wid;
	int n;

	if(r == 0)
		berror("NUL in charwidth");	

	if(r < Runeself){
		buf[0] = r;
		buf[1] = 0;
	}else{
		n = runetochar(buf, &r);
		buf[n] = 0;
	}
	p = buf;
	n = 0;
	while(cachechars(f, &p, &c, 1, &wid) <= 0)
		if(++n > 3)
			return 0;
	agefont(f);
	return wid;
}

void
agefont(Font *f)
{
	Cacheinfo *c, *ec;
	Cachesubf *s, *es;

	f->age++;
	if(f->age == 65536){
		/*
		 * Renormalize ages
		 */
		c = f->cache;
		ec = c+f->ncache;
		while(c < ec){
			if(c->age){
				c->age >>= 2;
				c->age++;
			}
			c++;
		}
		s = f->subf;
		es = s+f->nsubf;
		while(s < es){
			if(s->age){
				if(s->age<SUBFAGE && s->cf->name != nil){
					
					subffree(s->f);
					s->cf = nil;
					s->f = nil;
					s->age = 0;
				}else{
					s->age >>= 2;
					s->age++;
				}
			}
			s++;
		}
		f->age = (65536>>2) + 1;
	}
}


int
loadchar(Font *f, Rune r, Cacheinfo *c, int h, int noflush)
{
	int fd, i, oi, wid;
	Rune pic;
	Fontchar *fi;
	Cachefont *cf;
	Cachesubf *subf, *of;
	byte *b;

	pic = r;
    Again:
	for(i=0; i<f->nsub; i++){
		cf = f->sub[i];
		if(cf->min<=pic && pic<=cf->max)
			goto Found;
	}
    TryPJW:
	if(pic != PJW){
		pic = PJW;
		goto Again;
	}
	return 0;

    Found:
	/*
	 * Choose exact or oldest
	 */
	oi = 0;
	subf = &f->subf[0];
	for(i=0; i<f->nsubf; i++){
		if(cf == subf->cf)
			goto Found2;
		if(subf->age < f->subf[oi].age)
			oi = i;
		subf++;
	}
	subf = &f->subf[oi];

	if(subf->f){
		if(f->age-subf->age>SUBFAGE || f->nsubf>MAXSUBF){
    Toss:
			
			subffree(subf->f);
			subf->cf = nil;
			subf->f = nil;
			subf->age = 0;
		}else{				
			of = f->subf;
			f->subf = malloc((f->nsubf+DSUBF)*sizeof *subf);
			if(f->subf == nil){
				f->subf = of;
				goto Toss;
			}
			memmove(f->subf, of, (f->nsubf+DSUBF)*sizeof *subf);
			memset(f->subf+f->nsubf, 0, DSUBF*sizeof *subf);
			subf = &f->subf[f->nsubf];
			f->nsubf += DSUBF;
			free(of);
		}
	}
	subf->age = 0;
	subf->cf = nil;
	fd = -1;
	if(!cf->abs){
		byte tmp1[128], tmp2[128];
		byte *t, *u;
		/*
		 * prefix name with directory if necessary
		 * and try to find a file suffixed with the right ldepth.
		 */
		t = cf->name;
		if(t[0] != '/'){
			strcpy(tmp2, f->name);
			u = utfrrune(tmp2, '/');
			if(u)
				u[0] = 0;
			else
				strcpy(tmp2, ".");
			sprint(tmp1, "%s/%s", tmp2, t);
			t = tmp1;
		}
		sprint(tmp2, "%s.%d", t, f->ldepth);
		if(access(tmp2, 0) == 0)
			t = tmp2;
		else if(access(t, 0) < 0)
			goto Err;
		t = strdup(t);
		if(t == nil)
			goto Err;
		free(cf->name);
		cf->name = t;
		cf->abs = 1;
	}
	fd = open(cf->name, OREAD);
	if(fd < 0){
    Err:
		if(fd >= 0)
			close(fd);
		fprint(2, "loadchar: can't open %s: %r\n", cf->name);
		cf->min = 1;
		cf->max = 0;	
		goto TryPJW;
	}
	subf->f = rdsubfontfile(fd, nil);
	if(subf->f == nil){
		freeup(f);
		subf->f = rdsubfontfile(fd, nil);
		if(subf->f == nil){
			close(fd);
			goto Err;
		}
	}
	close(fd);
	subf->cf = cf;

    Found2:
	subf->age = f->age;

	pic += cf->offset;
	if(pic-cf->min >= subf->f->n)
		goto TryPJW;
	fi = &subf->f->info[pic - cf->min];
	if(fi->width == 0)
		goto TryPJW;
	wid = (fi+1)->x - fi->x;
	if(f->width < wid || f->width == 0){
		/*
		 * Flush, free, reload (easier than reformatting f->b)
		 */
		if(noflush)
			return -1;
		i = resize(f, wid, f->ncache);
		if(i <= 0)
			return i;
		
	}
	c->value = r;
	c->top = fi->top + (f->ascent-subf->f->ascent);
	c->bottom = fi->bottom + (f->ascent-subf->f->ascent);
	c->width = fi->width;
	c->left = fi->left;
	c->x = h*f->width;
	c->xright = c->x + wid;
	b = bneed(9);
	b[0] = 'y';
	BPSHORT(b+1, f->id);
	BPSHORT(b+3, h);
	BPSHORT(b+5, subf->f->id);
	BPSHORT(b+7, pic-cf->min);
	return 1;
}


intern int
freeup(Font *f)
{
	Cachesubf *s, *es;
	int nf;

	if(f->sub[0]->name == nil)	
		return 0;
	s = f->subf;
	es = s+f->nsubf;
	nf = 0;
	while(s < es){
		if(s->age){
			subffree(s->f);
			s->cf = nil;
			s->f = nil;
			s->age = 0;
			nf++;
		}
		s++;
	}
	return nf;
}


intern int
resize(Font *f, int wid, int ncache)
{
	byte *b;
	Cacheinfo *i;
	int nf, ret;

	b = bneed(7);
	b[0] = 'v';
	BPSHORT(b+1, f->id);
	BPSHORT(b+3, ncache);
	BPSHORT(b+5, wid);
	if(!bwrite()){
		
		nf = freeup(f);
		if(f != font)
			nf += freeup(font);
		if(wid != f->width){
			if(nf < 2){
				
				if(ncache != NFCACHE+NFLOOK){
					ret = resize(f, wid, NFCACHE+NFLOOK);
					if(ret >= 0)
						return ret;
				}
				berror("font resize failed");
			}
			return -1;	
		}
		
		ncache = f->ncache;
	}
    ok:
	f->width = wid;
	ret = 1;
	if(f->ncache != ncache){
		ret = 0;
		i = malloc(ncache*sizeof f->cache[0]);
		if(i){
			free(f->cache);
			f->ncache = ncache;
			f->cache = i;
		}
		
	}
	memset(f->cache, 0, f->ncache*sizeof f->cache[0]);
	return ret;
}
