
#define	CHAR(x)		*p++ = f->x
#define	SHORT(x)	p[0] = f->x; p[1] = f->x>>8; p += 2
#define	LONG(x)		p[0] = f->x; p[1] = f->x>>8; p[2] = f->x>>16; p[3] = f->x>>24; p += 4
#define	VLONG(x)	p[0] = f->x; p[1] = f->x>>8; p[2] = f->x>>16; p[3] = f->x>>24;\
				p[4] = 0; p[5] = 0; p[6] = 0; p[7] = 0; p += 8
#define	STRING(x,n)	memmove(p, f->x, n); p += n

int
convS2M(Fcall *f, byte *ap)
{
	byte *p;

	p = ap;
	CHAR(type);
	SHORT(tag);
	switch(f->type)
	{
	default:
		return 0;

	case Tosession:
	case Tnop:
		break;

	case Tsession:
		STRING(chal, sizeof(f->chal));
		break;

	case Tflush:
		SHORT(oldtag);
		break;

	case Tattach:
		SHORT(fid);
		STRING(uname, sizeof(f->uname));
		STRING(aname, sizeof(f->aname));
		STRING(ticket, sizeof(f->ticket));
		STRING(auth, sizeof(f->auth));
		break;

	case Toattach:
		SHORT(fid);
		STRING(uname, sizeof(f->uname));
		STRING(aname, sizeof(f->aname));
		STRING(ticket, NAMELEN);
		break;

	case Tauth:
		SHORT(fid);
		STRING(uname, sizeof(f->uname));
		STRING(ticket, 8+NAMELEN);
		break;

	case Tclone:
		SHORT(fid);
		SHORT(newfid);
		break;

	case Twalk:
		SHORT(fid);
		STRING(name, sizeof(f->name));
		break;

	case Topen:
		SHORT(fid);
		CHAR(mode);
		break;

	case Tcreate:
		SHORT(fid);
		STRING(name, sizeof(f->name));
		LONG(perm);
		CHAR(mode);
		break;

	case Tread:
		SHORT(fid);
		VLONG(offset);
		SHORT(count);
		break;

	case Twrite:
		SHORT(fid);
		VLONG(offset);
		SHORT(count);
		p++;	
		STRING(data, f->count);
		break;

	case Tclunk:
		SHORT(fid);
		break;

	case Tremove:
		SHORT(fid);
		break;

	case Tstat:
		SHORT(fid);
		break;

	case Twstat:
		SHORT(fid);
		STRING(stat, sizeof(f->stat));
		break;

	case Tclwalk:
		SHORT(fid);
		SHORT(newfid);
		STRING(name, sizeof(f->name));
		break;
/*
 */
	case Rosession:
	case Rnop:
		break;

	case Rsession:
		STRING(chal, sizeof(f->chal));
		STRING(authid, sizeof(f->authid));
		STRING(authdom, sizeof(f->authdom));
		break;

	case Rerror:
		STRING(ename, sizeof(f->ename));
		break;

	case Rflush:
		break;

	case Rattach:
		SHORT(fid);
		LONG(qid.path);
		LONG(qid.vers);
		STRING(rauth, sizeof(f->rauth));
		break;

	case Roattach:
		SHORT(fid);
		LONG(qid.path);
		LONG(qid.vers);
		break;

	case Rauth:
		SHORT(fid);
		STRING(ticket, 8+8+7+7);
		break;

	case Rclone:
		SHORT(fid);
		break;

	case Rwalk:
	case Rclwalk:
		SHORT(fid);
		LONG(qid.path);
		LONG(qid.vers);
		break;

	case Ropen:
		SHORT(fid);
		LONG(qid.path);
		LONG(qid.vers);
		break;

	case Rcreate:
		SHORT(fid);
		LONG(qid.path);
		LONG(qid.vers);
		break;

	case Rread:
		SHORT(fid);
		SHORT(count);
		p++;	
		STRING(data, f->count);
		break;

	case Rwrite:
		SHORT(fid);
		SHORT(count);
		break;

	case Rclunk:
		SHORT(fid);
		break;

	case Rremove:
		SHORT(fid);
		break;

	case Rstat:
		SHORT(fid);
		STRING(stat, sizeof(f->stat));
		break;

	case Rwstat:
		SHORT(fid);
		break;
	}
	return p - ap;
}
