

/*
 * Return pointer to first occurrence of s2 in s1,
 * 0 if none
 */
byte*
utfutf(byte *s1, byte *s2)
{
	byte *p;
	int f, n1, n2;
	Rune r;

	n1 = chartorune(&r, s2);
	f = r;
	if(f <= Runesync)		
		return strstr(s1, s2);

	n2 = strlen(s2);
	for(p=s1; p=utfrune(p, f); p+=n1)
		if(strncmp(p, s2, n2) == 0)
			return p;
	return nil;
}
