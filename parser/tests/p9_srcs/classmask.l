
byte classmask[4][4] = {
	{ 0xff, 0x00, 0x00, 0x00 },
	{ 0xff, 0x00, 0x00, 0x00 },
	{ 0xff, 0xff, 0x00, 0x00 },
	{ 0xff, 0xff, 0xff, 0x00 }
};

void
maskip(byte *a, byte *m, byte *n)
{
	int i;

	for(i = 0; i < 4; i++)
		n[i] = a[i] & m[i];
}