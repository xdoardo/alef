
/*	Form a circle of radius r centered at x1,y1
 *	The boundary is a sequence of vertically, horizontally,
 *	or diagonally adjacent points that minimize 
 *	abs(x^2+y^2-r^2).
 *
 *	The circle is guaranteed to be symmetric about
 *	the horizontal, vertical, and diagonal axes
 */

void
circle(Bitmap *b, Point p, int r, int v, Fcode f)
{
	int x1;
	int y1;
	int eps;		
	int dxsq;		
	int dysq;
	int exy;
	int x0;
	int y0;

	x1=p.x;
	y1=p.y;
	eps = 0;		
	dxsq = 1;		
	dysq = 1 - 2*r;
	x0 = x1;
	y0 = y1 - r;

	y1 += r;
	if(f > 0xF)
		f &= 0xF;
	if(r == 0){
		point(b, Pt(x0, y0), v, f);
		return;
	}
	point(b, Pt(x0, y0), v, f);
	point(b, Pt(x0, y1), v, f);
	goto advance;

	while(y1 > y0) {
		point(b, Pt(x0,y0), v, f);
		point(b, Pt(x0,y1), v, f);
		point(b, Pt(x1,y0), v, f);
		point(b, Pt(x1,y1), v, f);
	advance:
		exy = eps + dxsq + dysq;
		if(-exy <= eps+dxsq) {
			y1--;
			y0++;
			eps += dysq;
			dysq += 2;
		}
		if(exy <= -eps) {
			x1++;
			x0--;
			eps += dxsq;
			dxsq += 2;
		}
	}
	point(b, Pt(x0, y0), v, f);
	point(b, Pt(x1, y0), v, f);
}
