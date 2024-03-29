
void
Awin.new(Awin *a, byte *name)
{
	chan(int) c;

	alloc c;
	proc a->slave(name, c);
	<-c;	
	unalloc c;
}

void
Awin.slave(Awin *a, byte *name, chan(int) c)
{
	byte t[64];
	Event e, e2, *eq;
	byte *s, *buf;

	rfork(RFFDG);	
	a->wnew();
	while(*name == ' ')
		name++;
	sprint(t, "Acid/%s", name);
	a->wtagwrite(" Send Delete", 12);
	a->wname(t);
	a->wclean();
	a->wdormant();
	c <-= 1;
	for(;;){
		a->wevent(&e);
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
				eq = &e;
				if(e.flag & 2){
					a->wevent(&e2);
					eq = &e2;
				}
				buf = nil;
				s = eq->b;
				if(eq->q1>eq->q0 && eq->nb==0){
					buf = emalloc((eq->q1-eq->q0)*UTFmax+1);
					a->wread(eq->q0, eq->q1, buf);
					s = buf;
				}
				if(!a->command(s)){
					if(e.flag & 1)	
						a->wwriteevent(&e);
					else
						a->send(strlen(s), s, True);
				}
				if(buf)
					free(buf);
				break;

			case 'l':
			case 'L':
				if(e.flag & 2)
					a->wevent(&e2);
				
				a->wwriteevent(&e);
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
}

int
Awin.command(Awin *a, byte *s)
{
	byte *t;
	int n;

	while(*s==' ' || *s=='\t' || *s=='\n')
		s++;
	if(strcmp(s, "Send") == 0){
		(n, t) = a->wreadall();
		a->send(n, t, False);
		return True;
	}
	if(strcmp(s, "Del") == 0){
		if(a->wdel(False))
			terminate(nil);
		return True;
	}
	if(strcmp(s, "Delete") == 0){
		if(a->wdel(True))
			terminate(nil);
		return True;
	}
	return False;
}

void
Awin.send(Awin *a, int n, byte *s, int echo)
{

	USED(a);
	if(n > 0){
		if(echo){
			write(1, s, n);
			if(s[n-1] != '\n')
				write(1, "\n", 1);
		}
		if(write(stdin, s, n) != n)
			error("can't write stdin: %r\n");
		if(s[n-1] != '\n')
			write(stdin, "\n", 1);
		if(!echo){
			
			write(stdin, "\"\"\n", 3);
		}
	}
}
