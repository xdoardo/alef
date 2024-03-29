
intern void dumpsome(byte*, byte*, int);
intern void fdirconv(byte*, Dir*);

int
fcallconv(Printspec *p)
{
	Dir d;
	Fcall *f;
	byte *buf;
	int fid, type, tag, n;

	buf = malloc(2000);
	if(buf == nil)
		return sizeof(Fcall*);

	f = *(Fcall **)p->o;
	type = f->type;
	fid = f->fid;
	tag = f->tag;
	switch(type){
	case Tnop:	
		sprint(buf, "Tnop tag %ud", tag);
		break;
	case Rnop:
		sprint(buf, "Rnop tag %ud", tag);
		break;
	case Tsession:	
		sprint(buf, "Tsession tag %ud", tag);
		break;
	case Rsession:
		sprint(buf, "Rsession tag %ud", tag);
		break;
	case Rerror:	
		sprint(buf, "Rerror tag %ud error %.64s", tag, f->ename);
		break;
	case Tflush:	
		sprint(buf, "Tflush tag %ud oldtag %d", tag, f->oldtag);
		break;
	case Rflush:
		sprint(buf, "Rflush tag %ud", tag);
		break;
	case Tattach:	
		sprint(buf, "Tattach tag %ud fid %d uname %.28s aname %.28s auth %.28s",
			tag, f->fid, f->uname, f->aname, f->auth);
		break;
	case Rattach:
		sprint(buf, "Rattach tag %ud fid %d qid 0x%ux|0x%ux",
			tag, fid, f->qid.path, f->qid.vers);
		break;
	case Tclone:	
		sprint(buf, "Tclone tag %ud fid %d newfid %d", tag, fid, f->newfid);
		break;
	case Rclone:
		sprint(buf, "Rclone tag %ud fid %d", tag, fid);
		break;
	case Twalk:	
		sprint(buf, "Twalk tag %ud fid %d name %.28s", tag, fid, f->name);
		break;
	case Rwalk:
		sprint(buf, "Rwalk tag %ud fid %d qid 0x%ux|0x%ux",
			tag, fid, f->qid.path, f->qid.vers);
		break;
	case Topen:	
		sprint(buf, "Topen tag %ud fid %d mode %d", tag, fid, f->mode);
		break;
	case Ropen:
		sprint(buf, "Ropen tag %ud fid %d qid 0x%ux|0x%ux",
			tag, fid, f->qid.path, f->qid.vers);
		break;
	case Tcreate:	
		sprint(buf, "Tcreate tag %ud fid %d name %.28s perm 0x%ux mode %d",
			tag, fid, f->name, f->perm, f->mode);
		break;
	case Rcreate:
		sprint(buf, "Rcreate tag %ud fid %d qid 0x%ux|0x%ux",
			tag, fid, f->qid.path, f->qid.vers);
		break;
	case Tread:	
		sprint(buf, "Tread tag %ud fid %d offset %d count %d",
			tag, fid, f->offset, f->count);
		break;
	case Rread:
		n = sprint(buf, "Rread tag %ud fid %d count %d ", tag, fid, f->count);
		dumpsome(buf+n, f->data, f->count);
		break;
	case Twrite:	
		n = sprint(buf, "Twrite tag %ud fid %d offset %d count %d ",
			tag, fid, f->offset, f->count);
		dumpsome(buf+n, f->data, f->count);
		break;
	case Rwrite:
		sprint(buf, "Rwrite tag %ud fid %d count %d", tag, fid, f->count);
		break;
	case Tclunk:	
		sprint(buf, "Tclunk tag %ud fid %d", tag, fid);
		break;
	case Rclunk:
		sprint(buf, "Rclunk tag %ud fid %d", tag, fid);
		break;
	case Tremove:	
		sprint(buf, "Tremove tag %ud fid %d", tag, fid);
		break;
	case Rremove:
		sprint(buf, "Rremove tag %ud fid %d", tag, fid);
		break;
	case Tstat:	
		sprint(buf, "Tstat tag %ud fid %d", tag, fid);
		break;
	case Rstat:
		n = sprint(buf, "Rstat tag %ud fid %d", tag, fid);
		convM2D(f->stat, &d);
		sprint(buf+n, " stat ");
		fdirconv(buf+n+6, &d);
		break;
	case Twstat:	
		convM2D(f->stat, &d);
		n = sprint(buf, "Twstat tag %ud fid %d stat ", tag, fid);
		fdirconv(buf+n, &d);
		break;
	case Rwstat:
		sprint(buf, "Rwstat tag %ud fid %d", tag, fid);
		break;
	default:
		sprint(buf,  "unknown type %d", type);
	}
	strconv(p, buf);
	free(buf);
	return sizeof(Fcall*);
}

int
dirconv(Printspec *p)
{
	byte buf[160];

	fdirconv(buf, *(Dir**)p->o);
	strconv(p, buf);
	return(sizeof(Dir*));
}

intern void
fdirconv(byte *buf, Dir *d)
{
	sprint(buf, "'%s' '%s' '%s' q %#ux|%#ux m %#uo at %d mt %d l %d t %d d %d\n",
			d->name, d->uid, d->gid,
			d->qid.path, d->qid.vers, d->mode,
			d->atime, d->mtime, d->length,
			d->type, d->dev);
}

/*
 * dump out count (or DUMPL, if count is bigger) bytes from
 * buf to ans, as a string if they are all printable,
 * else as a series of hex bytes
 */
#define DUMPL 24

intern void
dumpsome(byte *ans, byte *buf, int count)
{
	byte *p, c;
	int i, printable;

	printable = 1;
	if(count > DUMPL)
		count = DUMPL;
	for(i=0; i<count && printable; i++) {
		c = buf[i];
		if((c < 32 && c !='\n' && c !='\t') || c > 127)
			printable = 0;
	}
	p = ans;
	*p++ = '\'';
	if(printable){
		memmove(p, buf, count);
		p += count;
	}else{
		for(i=0; i<count; i++){
			if(i>0 && i%4==0)
				*p++ = ' ';
			sprint(p, "%2.2ux", buf[i]);
			p += 2;
		}
	}
	*p++ = '\'';
	*p = 0;
}
