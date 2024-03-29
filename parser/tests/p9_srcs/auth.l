
intern byte *badreq = "bad ticket request";
intern byte *ccmsg = "can't connect to AS";
intern byte *srmsg = "server refused authentication";
intern byte *sgmsg = "server gave up";

int
auth(int fd)
{
	int n, afd;
	int rv;
	byte trbuf[TICKREQLEN];
	byte tbuf[2*TICKETLEN+AUTHENTLEN];
	Ticketreq tr;

	
	if(_asreadn(fd, trbuf, TICKREQLEN) < 0){
		werrstr(badreq);
		return -1;
	}
	convM2TR(trbuf, &tr);
	if(tr.type != AuthTreq){
		werrstr(badreq);
		return -1;
	}
	memset(tr.uid, 0, sizeof(tr.uid));
	strcpy(tr.uid, getuser());
	memset(tr.hostid, 0, sizeof(tr.hostid));
	_asrdfile("/dev/hostowner", tr.hostid, NAMELEN);
	convTR2M(&tr, trbuf);

	
	afd = authdial();
	if(afd < 0){
		werrstr(ccmsg);
		return -1;
	}
	rv = _asgetticket(afd, trbuf, tbuf);
	close(afd);
	if(rv) {
		werrstr("can't read ticket");
		return -1;
	}
	
	afd = open("/dev/authenticator", ORDWR);
	if(afd < 0){
		werrstr("/dev/authenticator: %r");
		return -1;
	}
	if(write(afd, tbuf, TICKETLEN) < 0){
		werrstr("writing /dev/authenticator: %r");
		return -1;
	}
	if(read(afd, tbuf+2*TICKETLEN, AUTHENTLEN) < 0){
		werrstr("reading /dev/authenticator: %r");
		return -1;
	}

	
	if(write(fd, tbuf+TICKETLEN, TICKETLEN+AUTHENTLEN) < 0){
		werrstr("%s:%r", srmsg);
		return -1;
	}

	
	if(_asreadn(fd, tbuf+TICKETLEN, AUTHENTLEN) < 0){
		werrstr(sgmsg);
		return -1;
	}
	afd = open("/dev/authcheck", ORDWR);
	if(afd < 0){
		werrstr("authcheck: %r");
		return -1;
	}
	n = write(afd, tbuf, TICKETLEN+AUTHENTLEN);
	close(afd);
	if(n < 0){
		memset(tbuf, 0, AUTHENTLEN);
		if(memcmp(tbuf, tbuf+TICKETLEN, AUTHENTLEN) == 0)
			werrstr("refused by server");
		else
			werrstr("server lies");
		return -1;
	}
	return 0;
}
