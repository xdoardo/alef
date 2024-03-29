
void
frselect(Frame *f, Bitmap *t, Mouse *m)	
{
	uint p0, p1, q;
	Point mp, pt0, pt1, qt;
	int b, scrled;

	mp = m->xy;
	b = m->buttons;

    Again:
	f->modified = 0;
	frselectp(f, t, S^D);
	p0 = p1 = frcharofpt(f, mp);
	pt0 = frptofchar(f, p0);
	pt1 = frptofchar(f, p1);
	frselectf(f, pt0, pt1, t, S^D);
	do{
		scrled = 0;
		if(f->scroll){
			if(m->xy.y < f->r.min.y){
				(*f->scroll)(f, -(f->r.min.y-m->xy.y)/(int)f->font->height-1);
				p0 = f->p1;
				p1 = f->p0;
				scrled = 1;
			}else if(m->xy.y > f->r.max.y){
				(*f->scroll)(f, (m->xy.y-f->r.max.y)/(int)f->font->height+1);
				p0 = f->p0;
				p1 = f->p1;
				scrled = 1;
			}
			if(scrled){
				pt0 = frptofchar(f, p0);
				pt1 = frptofchar(f, p1);
			}
		}
		q = frcharofpt(f, m->xy);
		if(p1 != q){
			if(p0 == p1)
				frselectf(f, pt0, pt1, t, S^D);
			qt = frptofchar(f, q);
			if(p1 < q)
				frselectf(f, pt1, qt, t, S^D);
			else
				frselectf(f, qt, pt1, t, S^D);
			p1 = q;
			pt1 = qt;
			if(p0 == p1)
				frselectf(f, pt0, pt1, t, S^D);
		}
		f->modified = 0;
		if(p0 < p1) {
			f->p0 = p0;
			f->p1 = p1;
		}
		else {
			f->p0 = p1;
			f->p1 = p0;
		}
		if(scrled)
			(*f->scroll)(f, 0);
		else
			frgetmouse();
	}while(m->buttons == b);
}


void
frselectf(Frame *f, Point p0, Point p1, Bitmap *t, Fcode c)
{
	int n;
	Point q0, q1;

	if(p0.x == f->left)
		p0.x = f->r.min.x;
	if(p1.x == f->left)
		p1.x = f->r.min.x;
	q0 = p0;
	q1 = p1;
	q0.y += f->font->height;
	q1.y += f->font->height;
	n = (p1.y-p0.y)/f->font->height;
	if(f->b == nil)
		berror("frselectf b==0");
	if(p0.y == f->r.max.y)
		return;
	if(n == 0){
		if(p0.x == p1.x)
			if(p0.x == f->r.min.x)
				q1.x++;
			else
				p0.x--;
		texture(f->b, Rect(p0.x, p0.y, q1.x, q1.y), t, c);
	}else{
		texture(f->b, Rect(p0.x, p0.y, f->r.max.x, q0.y), t, c);
		if(n > 1)
			texture(f->b, Rect(f->r.min.x, q0.y, f->r.max.x, p1.y), t, c);
		texture(f->b, Rect(f->r.min.x, p1.y, q1.x, q1.y), t, c);
	}
}

void
frselectp(Frame *f, Bitmap *t, Fcode c)
{
	Point pt0, pt1;

	pt0 = frptofchar(f, f->p0);
	if(f->p0 == f->p1)
		pt1 = pt0;
	else
		pt1 = frptofchar(f, f->p1);

	frselectf(f, pt0, pt1, t, c);
}
