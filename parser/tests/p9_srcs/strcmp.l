
int
strcmp(byte *s1, byte *s2)
{
	uint c1, c2;

	for(;;) {
		c1 = *s1++;
		c2 = *s2++;
		if(c1 != c2) {
			if(c1 > c2)
				return 1;
			return -1;
		}
		if(c1 == 0)
			return 0;
	}
}
