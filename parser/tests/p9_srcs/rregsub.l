

extern	void
rregsub(Rune *sp,	
	Rune *dp,	
	Resub *mp,	
	int ms)		
{
	Rune *ssp;
	int i;

	while(*sp != '\0'){
		if(*sp == '\\'){
			switch(*++sp){
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
			case '8':
			case '9':
				i = *sp-'0';
				if(mp[i].rsp != nil && mp!=nil && ms>i)
					for(ssp = mp[i].rsp;
					     ssp < mp[i].rep;
					     ssp++)
						*dp++ = *ssp;
				break;
			case '\\':
				*dp++ = '\\';
				break;
			case '\0':
				sp--;
				break;
			default:
				*dp++ = *sp;
				break;
			}
		}else if(*sp == '&'){				
			if(mp[0].rsp != nil && mp!=nil && ms>0)
			if(mp[0].rsp != nil)
				for(ssp = mp[0].rsp;
				     ssp < mp[0].rep; ssp++)
					*dp++ = *ssp;
		}else
			*dp++ = *sp;
		sp++;
	}
	*dp = '\0';
}
