
Box*
Box.read(byte *f, int readonly)
{
	Box *b;
	Mesg *m;
	int n;
	byte buf[512], *s;

	b = malloc(sizeof(Box));
	b->readonly = readonly;
	b->file = strdup(f);
	b->io = Bopen(f, OREAD|OCEXEC);
	if(b->io == nil)
		error("can't open %s: %r", f);
	while((m = m->read(b)) != nil){
		m->next = b->m;
		b->m = m;
		b->nm++;
		m->id = b->nm;
	}
	b->len = b->io->offset();
	b->io->term();
	b->io = nil;
	b->wnew();
	for(m=b->m; m; m=m->next){
		if(m->subj)
			n = sprint(buf, "%d\t%.*s\t %s", m->id, m->lline1, m->hdr, m->subj);
		else
			n = sprint(buf, "%d\t%.*s", m->id, m->lline1, m->hdr);
		b->wwritebody(buf, n);
	}
	s = utfrrune(f, '/');
	if(s)
		s++;
	else
		s = f;
	sprint(buf, "Mail/%s/", s);
	b->wname(buf);
	if(b->readonly)
		b->wtagwrite("Mail", 4);
	else
		b->wtagwrite("Put Mail", 8);
	sprint(buf, "Mail %s", f);
	b->wsetdump("/acme/mail", buf);
	b->wclean();
	b->wselect("0");
	b->wdormant();
	alloc b->cdel;
	alloc b->cevent;
	alloc b->cmore;
	proc b->wslave(b->cevent);
	b->clean = True;
	return b;
}

void
Box.readmore(Box *b)
{
	Mesg *m;
	int new, n;
	byte buf[512];
	int doclose;

	doclose = False;
	if(b->io == nil){
		b->io = Bopen(b->file, OREAD|OCEXEC);
		if(b->io == nil)
			error("can't open %s: %r", b->file);
		b->io->seek(b->len, 0);
		doclose = True;
	}
	new = False;
	while((m = m->read(b)) != nil){
		m->next = b->m;
		b->m = m;
		b->nm++;
		m->id = b->nm;
		if(m->subj)
			n = sprint(buf, "%d\t%.*s\t  %s", m->id, m->lline1, m->hdr, m->subj);
		else
			n = sprint(buf, "%d\t%.*s", m->id, m->lline1, m->hdr);
		b->wreplace("0", buf, n);
		new = True;
	}
	b->len = b->io->offset();
	if(doclose){
		b->io->term();
		b->io = nil;
	}
	if(new){
		if(b->clean)
			b->wclean();
		b->wselect("0;/.*(\\n[ \t].*)*");
		b->wshow();
	}
	b->wdormant();
}

(int, byte*)
Box.readline(Box *b)
{
	int c;

    loop:
	if(b->freeline){
		free(b->line);
		b->freeline = False;
	}
	if(b->peeklinelen){
		b->line = b->peekline;
		b->linelen = b->peeklinelen;
		b->freeline = b->peekfreeline;
		b->peekline = nil;
		b->peeklinelen = 0;
		b->peekfreeline = False;
	}else{
		b->line = b->io->rdline('\n');
		b->linelen = b->io->linelen();
		
		if(b->line==nil && b->linelen>0){
			b->line = malloc(b->linelen);
			b->freeline = True;
			b->io->read(b->line, b->linelen);
			while((c=b->io->getc()) != Beof){
				b->line = realloc(b->line, b->linelen+1);
				b->line[b->linelen++] = c;
				if(c == '\n')	
					break;
			}
		}
	}
	
	if(b->line && memchr(b->line, 0, b->linelen))
		goto loop;
	return (b->linelen, b->line);
}

void
Box.unreadline(Box *b)
{
	b->peekline = b->line;
	b->peeklinelen = b->linelen;
	b->peekfreeline = b->freeline;
	b->freeline = False;
}

void
Box.slave(Box *b)
{
	Event e;
	Mesg *m;

	for(;;){
		alt{
		case e = <-b->cevent:
			b->event(e);
			break;
		case <-b->cmore:
			b->readmore();
			break;
		case m = <-b->cdel:
			b->mdel(m);
			break;
		}
	}
}

void
Box.event(Box *b, Event e)
{
	Event e2, ea, *eq;
	byte *s, *t, *buf;
	int n, na, nopen;

	switch(e.c1){
	default:
	Unknown:
		print("unknown message %c%c\n", e.c1, e.c2);
		break;

	case 'E':	
		break;

	case 'F':	
		break;

	case 'K':	
		break;

	case 'M':
		switch(e.c2){
		case 'x':
		case 'X':
			if(e.flag & 2)
				e2 = <-b->cevent;
			if(e.flag & 8){
				ea = <-b->cevent;
				na = ea.nb;
				<- b->cevent;
			}else
				na = 0;
			s = e.b;
			
			if((e.flag&2) && e.nb==0)
				s = e2.b;
			if(na){
				t = malloc(strlen(s)+1+na+1);
				sprint(t, "%s %s", s, ea.b);
				s = t;
			}
			
			if(!b->command(s))	
				b->wwriteevent(&e);
			if(na)
				free(s);
			break;

		case 'l':
		case 'L':
			eq = &e;
			if(e.flag & 2){
				e2 = <-b->cevent;
				eq = &e2;
			}
			buf = nil;
			s = eq->b;
			if(eq->q1>eq->q0 && eq->nb==0){
				buf = malloc((eq->q1-eq->q0)*UTFmax+1);
				b->wread(eq->q0, eq->q1, buf);
				s = buf;
			}
			nopen = 0;
			do{
				t = s;
				n = strtoi(s, &t, 10);
				if(n>0 && (*t==0 || *t==' ' || *t=='\t' || *t=='\n')){
					b->mopen(n);
					nopen++;
					s = t;
				}
				while(*s!=0 && *s++!='\n')
					;
			}while(*s);
			if(nopen == 0)	
				b->wwriteevent(&e);
			if(buf)
				free(buf);
			break;

		case 'I':	
		case 'D':
		case 'd':
		case 'i':
			break;

		default:
			goto Unknown;
		}
	}
}

void
Box.mopen(Box *b, int id)
{
	Mesg *m;

	for(m=b->m; m; m=m->next)
		if(m->id == id){
			m->open();
			break;
		}
}

void
Box.mdel(Box *b, Mesg *dm)
{
	Mesg *prev, *m;
	byte buf[32];

	if(dm->id){
		prev = nil;
		for(m=b->m; m!=nil && m!=dm; m=m->next)
			prev = m;
		if(m == nil)
			error("message %d not found", dm->id);
		if(prev == nil)
			b->m = m->next;
		else
			prev->next = m->next;
		
		sprint(buf, "/^%d	.*\\n(^[ \t].*\\n)*/", m->id);
		b->wreplace(buf, "", 0);
	}
	dm->free();
	b->clean = False;
}

int
Box.command(Box *b, byte *s)
{
	byte buf[256];
	int fd;
	byte *t;
	Mesg *m;

	while(*s==' ' || *s=='\t' || *s=='\n')
		s++;
	if(strncmp(s, "Mail", 4) == 0){
		s += 4;
		while(*s==' ' || *s=='\t' || *s=='\n')
			s++;
		t = s;
		while(*s && *s!=' ' && *s!='\t' && *s!='\n')
			s++;
		*s = 0;
		b->m->mkmail(b, t);
		return True;
	}
	if(strcmp(s, "Del") == 0){
		if(!b->clean){
			b->clean = True;
			fprint(2, "mail: mailbox not written\n");
			return True;
		}
		sprint(buf, "/proc/%d/notepg", getpid());
		fd = open(buf, OWRITE);
		rfork(RFNOTEG);
		write(fd, "kill", 4);
		b->wdel(True);
		for(m=b->m; m; m=m->next)
			m->wdel(False);
		exits(nil);
		return True;
	}
	if(strcmp(s, "Put") == 0){
		if(b->readonly)
			fprint(2, "Mail: %s is read-only\n", b->file);
		else
			b->rewrite();
		return True;
	}
	return False;
}

void
Box.rewrite(Box *b)
{
	int Lmbox, mbox, mboxtmp, i;
	byte buf[128];
	byte *s;
	Mesg *m;
	Dir d;

	if(b->clean){
		b->wclean();
		return;
	}
	s = utfrrune(b->file, '/');
	if(s)
		s++;
	else
		s = b->file;
	if(strcmp(mboxfile, usermboxfile) == 0){
		sprint(buf, "%.*sL.%s", s-b->file, b->file, s);
		Lmbox = openlockfile(buf);
		if(Lmbox < 0)
			error("can't open lock file %s: %r", buf);
	}else
		Lmbox = -1;
	sprint(buf, "%.*s%s.tmp", s-b->file, b->file, s);
	b->io = malloc(sizeof(Biobuf));
	mbox = tryopen(mboxfile, OREAD);
	if(mbox >= 0){
		b->io->init(mbox, OREAD);
		b->io->seek(b->len, 0);
		b->readmore();
	}else if(access(buf, 0)){
		fprint(2, "mail: mailbox missing; using %s\n", buf);
		mboxtmp = tryopen(buf, ORDWR);
		b->io->init(mboxtmp, OREAD);
		b->readmore();
		b->io->term();
	}else
		error("can't open %s to rewrite: %r", s);
	remove(buf);
	mboxtmp = create(buf, OWRITE, 0622|CHAPPEND|CHEXCL);
	if(mboxtmp < 0)
			error("can't create %s: %r", buf);
	if(dirfstat(mboxtmp, &d) < 0)
		error("can't fstat %s: %r", buf);
	d.mode |= 0622;
	if(dirfwstat(mboxtmp, &d) < 0)
		error("can't change mode of %s: %r", buf);
	b->io->init(mboxtmp, OWRITE);
	
	for(i=1; i<=b->nm; i++){
		for(m=b->m; m!=nil && m->id!=i; m=m->next)
			;
		if(m){
			b->io->write(m->realhdr, m->lrealhdr);
			b->io->write(m->text, m->ltext);
		}
	}
	if(remove(mboxfile) < 0)
		error("can't unlink %s: %r", mboxfile);
	strcpy(d.name, s);
	if(dirfwstat(mboxtmp, &d) < 0)
		error("can't change name of %s: %r", buf);
	b->len = b->io->offset();
	b->io->term();
	close(mboxtmp);
	free(b->io);
	b->io = nil;
	if(Lmbox >= 0)
		close(Lmbox);
	b->wclean();
	b->clean = True;
}
