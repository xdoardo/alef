
intern byte *ccmsg = "can't connect to AS";

int
authenticate(int fd, int afd)
{
	int rv;
	byte trbuf[TICKREQLEN];
	byte tbuf[2*TICKETLEN];

	if(fsession(fd, trbuf) < 0){
		werrstr("fsession: %r");
		return -1;
	}

	
	memset(tbuf, 0, 2*TICKETLEN);
	if(trbuf[0] == 0)
		return 0;

	
	if(afd >= 0)
		return _asgetticket(afd, trbuf, tbuf);
	afd = authdial();
	if(afd < 0){
		werrstr(ccmsg);
		return -1;
	}
	rv = _asgetticket(afd, trbuf, tbuf);
	close(afd);
	if(rv < 0)
		return -1;
	return fauth(fd, tbuf);
}
