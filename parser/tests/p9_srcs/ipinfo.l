
intern byte noether[6];

/*
 *  Look for a pair with the given attribute.  look first on the same line,
 *  then in the whole entry.
 */
intern Ndbtuple*
lookval(Ndbtuple *entry, Ndbtuple *line, byte *attr, byte *to)
{
	Ndbtuple *nt;

	
	for(nt = line;;){
		if(strcmp(attr, nt->attr) == 0){
			strncpy(to, nt->val, Ndbvlen);
			return nt;
		}
		nt = nt->line;
		if(nt == line)
			break;
	}
	
	for(nt = entry; nt; nt = nt->entry)
		if(strcmp(attr, nt->attr) == 0){
			strncpy(to, nt->val, Ndbvlen);
			return nt;
		}
	return nil;
}

/*
 *  lookup an ip address
 */
intern byte*
lookupip(Ndb *db, byte *name, byte *to)
{
	Ndbtuple *t;
	byte buf[Ndbvlen];
	Ndbs s;
	byte *attr;

	attr = ipattr(name);
	if(strcmp(attr, "ip") == 0){
		parseip(to, name);
		return to;
	}

	t = ndbgetval(db, &s, attr, name, "ip", buf);
	if(t){
		ndbfree(t);
		parseip(to, buf);
		return to;
	}
	return nil;
}

/*
 *  find out everything we can about a system from what has been
 *  specified.
 */
int
ipinfo(Ndb *db, byte *etherin, byte *ipin, byte *name, Ipinfo *iip)
{
	Ndbs s, ss;
	int foundether;
	Ndbtuple *t, *st;
	byte ether[Ndbvlen], ip[Ndbvlen];
	byte fsname[Ndbvlen], gwname[Ndbvlen], auname[Ndbvlen];

	memset(iip, 0, sizeof(Ipinfo));
	fsname[0] = 0;
	gwname[0] = 0;
	auname[0] = 0;

	/*
	 *  look for a matching entry
	 */
	t = nil;
	if(etherin){
		foundether = 1;
		t = ndbgetval(db, &s, "ether", etherin, "ip", ip);
	} else
		foundether = 0;
	if(t == nil && ipin != nil)
		t = ndbsearch(db, &s, "ip", ipin);
	if(t == nil && name != nil)
		t = ndbgetval(db, &s, ipattr(name), name, "ip", ip);
	if(t == nil)
		return -1;

	/*
	 *  don't allow conflicts
	 */
	if(t && etherin && foundether == 0){
		lookval(t, s.t, "ether", ether);
		if(strcmp(etherin, ether) != 0){
			ndbfree(t);
			return -1;
		}
	}

	if(lookval(t, s.t, "ip", ip))
		parseip(iip->ipaddr, ip);
	if(lookval(t, s.t, "ether", ether))
		parseether(iip->etheraddr, ether);
	lookval(t, s.t, "dom", iip->domain);

	/*
	 *  Look for bootfile, fs, and gateway.
	 *  If necessary, search through all entries for
	 *  this ip address.
	 */
	while(t){
		if(iip->bootf[0] == 0)
			lookval(t, s.t, "bootf", iip->bootf);
		if(fsname[0] == 0)
			lookval(t, s.t, "fs", fsname);
		if(gwname[0] == 0)
			lookval(t, s.t, "ipgw", gwname);
		if(auname[0] == 0)
			lookval(t, s.t, "auth", auname);
		ndbfree(t);
		if(iip->bootf[0] && fsname[0] && gwname[0] && auname[0])
			break;
		t = ndbsnext(&s, "ether", ether);
	}

	/*
	 *  Look up the client's network and find a subnet mask for it.
	 *  Fill in from the subnet (or net) entry anything we can't figure
	 *  out from the client record.
	 */
	maskip(iip->ipaddr, classmask[CLASS(iip->ipaddr)], iip->ipnet);
	memmove(iip->ipmask, classmask[CLASS(iip->ipaddr)], 4);
	sprint(ip, "%I", iip->ipnet);
	t = ndbsearch(db, &s, "ip", ip);
	if(t){
		
		if(lookval(t, s.t, "ipmask", ip)){
			parseip(iip->ipmask, ip);
			maskip(iip->ipaddr, iip->ipmask, iip->ipnet);
			sprint(ip, "%I", iip->ipnet);
			st = ndbsearch(db, &ss, "ip", ip);
			if(st){
				
				if(gwname[0] == 0)
					lookval(st, ss.t, "ipgw", gwname);
				if(fsname[0] == 0)
					lookval(st, ss.t, "fs", fsname);
				if(auname[0] == 0)
					lookval(st, ss.t, "auth", auname);
				ndbfree(st);
			}
		}
			

		
		if(gwname[0] == 0)
			lookval(t, s.t, "ipgw", gwname);
		if(fsname[0] == 0)
			lookval(t, s.t, "fs", fsname);
		if(auname[0] == 0)
			lookval(t, s.t, "auth", auname);
		ndbfree(t);
	}
	maskip(iip->ipaddr, iip->ipmask, iip->ipnet);

	
	if(fsname[0])
		lookupip(db, fsname, iip->fsip);
	if(gwname[0])
		lookupip(db, gwname, iip->gwip);
	if(auname[0])
		lookupip(db, auname, iip->auip);
	return 0;
}
