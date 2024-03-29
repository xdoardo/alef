
enum
{
	Bit1	= 7,
	Bitx	= 6,
	Bit2	= 5,
	Bit3	= 4,
	Bit4	= 3,

	T1	= ((1<<(Bit1+1))-1) ^ 0xFF,	
	Tx	= ((1<<(Bitx+1))-1) ^ 0xFF,	
	T2	= ((1<<(Bit2+1))-1) ^ 0xFF,	
	T3	= ((1<<(Bit3+1))-1) ^ 0xFF,	
	T4	= ((1<<(Bit4+1))-1) ^ 0xFF,	

	Rune1	= (1<<(Bit1+0*Bitx))-1,		
	Rune2	= (1<<(Bit2+1*Bitx))-1,		
	Rune3	= (1<<(Bit3+2*Bitx))-1,		

	Maskx	= (1<<Bitx)-1,			
	Testx	= Maskx ^ 0xFF,			

	Bad	= Runeerror,
};

int
chartorune(Rune *rune, byte *str)
{
	int c, c1, c2;
	int l;

	/*
	 * one character sequence
	 *	00000-0007F => T1
	 */
	c = *str;
	if(c < Tx) {
		*rune = c;
		return 1;
	}

	/*
	 * two character sequence
	 *	0080-07FF => T2 Tx
	 */
	c1 = *(str+1) ^ Tx;
	if(c1 & Testx)
		goto bad;
	if(c < T3) {
		if(c < T2)
			goto bad;
		l = ((c << Bitx) | c1) & Rune2;
		if(l <= Rune1)
			goto bad;
		*rune = l;
		return 2;
	}

	/*
	 * three character sequence
	 *	0800-FFFF => T3 Tx Tx
	 */
	c2 = *(str+2) ^ Tx;
	if(c2 & Testx)
		goto bad;
	if(c < T4) {
		l = ((((c << Bitx) | c1) << Bitx) | c2) & Rune3;
		if(l <= Rune2)
			goto bad;
		*rune = l;
		return 3;
	}

	/*
	 * bad decoding
	 */
bad:
	*rune = Bad;
	return 1;
}

int
runetochar(byte *str, Rune *rune)
{
	int c;

	/*
	 * one character sequence
	 *	00000-0007F => 00-7F
	 */
	c = *rune;
	if(c <= Rune1) {
		str[0] = c;
		return 1;
	}

	/*
	 * two character sequence
	 *	0080-07FF => T2 Tx
	 */
	if(c <= Rune2) {
		str[0] = T2 | (c >> 1*Bitx);
		str[1] = Tx | (c & Maskx);
		return 2;
	}

	/*
	 * three character sequence
	 *	0800-FFFF => T3 Tx Tx
	 */
	str[0] = T3 |  (c >> 2*Bitx);
	str[1] = Tx | ((c >> 1*Bitx) & Maskx);
	str[2] = Tx |  (c & Maskx);
	return 3;
}

int
runelen(int c)
{
	Rune rune;
	byte str[10];

	rune = c;
	return runetochar(str, &rune);
}

int
fullrune(byte *str, int n)
{
	int c;

	if(n > 0) {
		c = *str;
		if(c < Tx)
			return 1;
		if(n > 1)
			if(c < T3 || n > 2)
				return 1;
	}
	return 0;
}
