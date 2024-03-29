
uint
parseip(byte *to, byte *from)
{
	int i;
	byte *p;

	p = from;
	memset(to, 0, 4);
	for(i = 0; i < 4 && *p; i++){
		to[i] = strtoui(p, &p, 0);
		if(*p == '.')
			p++;
	}

	switch(CLASS(to)){
	case 0:	
	case 1:
		if(i == 3){
			to[3] = to[2];
			to[2] = to[1];
			to[1] = 0;
		} else if (i == 2){
			to[3] = to[1];
			to[1] = 0;
		}
		break;
	case 2:	
		if(i == 3){
			to[3] = to[2];
			to[2] = 0;
		}
		break;
	}
	return nhgetl(to);
}
