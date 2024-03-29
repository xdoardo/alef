
Rangeset	sel;
Rune		*lastregexp;

/*
 * Machine Information
 */
aggr Inst
{
	uint	type;	
	union {
		int sid;
		int subid;
		int class;
		Inst *other;
		Inst *right;
	};
	union{
		Inst *left;
		Inst *next;
	};
};

#define	NPROG	1024
Inst	program[NPROG];
Inst	*progp;
Inst	*startinst;	
Inst	*bstartinst;	
chan(Inst*)	rechan;

aggr Ilist
{
	Inst	*inst;		
	Rangeset se;
	uint	startp;		
};

#define	NLIST	128

Ilist	*tl, *nl;	
Ilist	list[2][NLIST];
intern	Rangeset sempty;

/*
 * Actions and Tokens
 *
 *	0x100xx are operators, value == precedence
 *	0x200xx are tokens, i.e. operands for operators
 */
#define	OPERATOR	0x10000	
#define	START		0x10000	
#define	RBRA		0x10001	
#define	LBRA		0x10002	
#define	OR		0x10003	
#define	CAT		0x10004	
#define	STAR		0x10005	
#define	PLUS		0x10006	
#define	QUEST		0x10007	
#define	ANY		0x20000	
#define	NOP		0x20001	
#define	BOL		0x20002	
#define	EOL		0x20003	
#define	CCLASS		0x20004	
#define	NCCLASS		0x20005	
#define	END		0x20077	

#define	ISATOR		0x10000
#define	ISAND		0x20000

/*
 * Parser Information
 */
aggr Node
{
	Inst	*first;
	Inst	*last;
};

#define	NSTACK	20
Node	andstack[NSTACK];
Node	*andp;
int	atorstack[NSTACK];
int	*atorp;
int	lastwasand;	
int	cursubid;
int	subidstack[NSTACK];
int	*subidp;
int	backwards;
int	nbra;
Rune	*exprp;		
#define	DCLASS	10	
int	nclass;		
int	Nclass;		
Rune	**class;
int	negateclass;

void	addinst(Ilist *l, Inst *inst, Rangeset *sep);
void	newmatch(Rangeset*);
void	bnewmatch(Rangeset*);
void	pushand(Inst*, Inst*);
void	pushator(int);
Node	*popand(int);
int	popator();
void	startlex(Rune*);
int	lex();
void	operator(int);
void	operand(int);
void	evaluntil(int);
void	optimize(Inst*);
void	bldcclass();

void
rxinit()
{
	alloc rechan;
	lastregexp = runemalloc(1);
}

void
regerror(byte *e)
{
	lastregexp[0] = 0;
	warning(nil, "regexp: %s\n", e);
	rechan <-= nil;
	terminate(nil);
}

Inst *
newinst(int t)
{
	if(progp >= &program[NPROG])
		regerror("expression too long");
	progp->type = t;
	progp->left = nil;
	progp->right = nil;
	return progp++;
}

void
realcompile(Rune *s)
{
	int token;

	startlex(s);
	atorp = atorstack;
	andp = andstack;
	subidp = subidstack;
	cursubid = 0;
	lastwasand = FALSE;
	
	pushator(START-1);
	while((token=lex()) != END){
		if((token&ISATOR) == OPERATOR)
			operator(token);
		else
			operand(token);
	}
	
	evaluntil(START);
	
	operand(END);
	evaluntil(START);
	if(nbra)
		regerror("unmatched `('");
	--andp;	
	rechan <-= andp->first;
}


int
rxcompile(Rune *r)
{
	int i, nr;
	Inst *oprogp;

	nr = runestrlen(r)+1;
	if(runeeq(lastregexp, runestrlen(lastregexp)+1, r, nr)==TRUE)
		return TRUE;
	lastregexp[0] = 0;
	for(i=0; i<nclass; i++)
		free(class[i]);
	nclass = 0;
	progp = program;
	backwards = FALSE;
	bstartinst = nil;
	task realcompile(r);
	startinst = <-rechan;
	if(startinst == nil)
		return FALSE;
	optimize(program);
	oprogp = progp;
	backwards = TRUE;
	task realcompile(r);
	bstartinst = <-rechan;
	if(bstartinst == nil)
		return FALSE;
	optimize(oprogp);
	lastregexp = runerealloc(lastregexp, nr);
	runemove(lastregexp, r, nr);
	return TRUE;
}

void
operand(int t)
{
	Inst *i;
	if(lastwasand)
		operator(CAT);	
	i = newinst(t);
	if(t == CCLASS){
		if(negateclass)
			i->type = NCCLASS;	
		i->class = nclass-1;		
	}
	pushand(i, i);
	lastwasand = TRUE;
}

void
operator(int t)
{
	if(t==RBRA && --nbra<0)
		regerror("unmatched `)'");
	if(t==LBRA){
		cursubid++;	
		nbra++;
		if(lastwasand)
			operator(CAT);
	}else
		evaluntil(t);
	if(t!=RBRA)
		pushator(t);
	lastwasand = FALSE;
	if(t==STAR || t==QUEST || t==PLUS || t==RBRA)
		lastwasand = TRUE;	
}

void
pushand(Inst *f, Inst *l)
{
	if(andp >= &andstack[NSTACK])
		error("operand stack overflow");
	andp->first = f;
	andp->last = l;
	andp++;
}

void
pushator(int t)
{
	if(atorp >= &atorstack[NSTACK])
		error("operator stack overflow");
	*atorp++=t;
	if(cursubid >= NRange)
		*subidp++= -1;
	else
		*subidp++=cursubid;
}

Node *
popand(int op)
{
	byte buf[64];

	if(andp <= &andstack[0])
		if(op){
			sprint(buf, "missing operand for %c", op);
			regerror(buf);
		}else
			regerror("malformed regexp");
	return --andp;
}

int
popator()
{
	if(atorp <= &atorstack[0])
		error("operator stack underflow");
	--subidp;
	return *--atorp;
}

void
evaluntil(int pri)
{
	Node *op1, *op2;
	Inst *inst1, *inst2;

	while(pri==RBRA || atorp[-1]>=pri){
		switch(popator()){
		case LBRA:
			op1 = popand('(');
			inst2 = newinst(RBRA);
			inst2->subid = *subidp;
			op1->last->next = inst2;
			inst1 = newinst(LBRA);
			inst1->subid = *subidp;
			inst1->next = op1->first;
			pushand(inst1, inst2);
			return;		
		default:
			error("unknown regexp operator");
			break;
		case OR:
			op2 = popand('|');
			op1 = popand('|');
			inst2 = newinst(NOP);
			op2->last->next = inst2;
			op1->last->next = inst2;
			inst1 = newinst(OR);
			inst1->right = op1->first;
			inst1->left = op2->first;
			pushand(inst1, inst2);
			break;
		case CAT:
			op2 = popand(0);
			op1 = popand(0);
			if(backwards && op2->first->type!=END)
				(op1, op2) = (op2, op1);
			op1->last->next = op2->first;
			pushand(op1->first, op2->last);
			break;
		case STAR:
			op2 = popand('*');
			inst1 = newinst(OR);
			op2->last->next = inst1;
			inst1->right = op2->first;
			pushand(inst1, inst1);
			break;
		case PLUS:
			op2 = popand('+');
			inst1 = newinst(OR);
			op2->last->next = inst1;
			inst1->right = op2->first;
			pushand(op2->first, inst1);
			break;
		case QUEST:
			op2 = popand('?');
			inst1 = newinst(OR);
			inst2 = newinst(NOP);
			inst1->left = inst2;
			inst1->right = op2->first;
			op2->last->next = inst2;
			pushand(inst1, inst2);
			break;
		}
	}
}


void
optimize(Inst *start)
{
	Inst *inst, *target;

	for(inst=start; inst->type!=END; inst++){
		target = inst->next;
		while(target->type == NOP)
			target = target->next;
		inst->next = target;
	}
}

void
startlex(Rune *s)
{
	exprp = s;
	nbra = 0;
}


int
lex(){
	int c;

	c = *exprp++;
	switch(c){
	case '\\':
		if(*exprp)
			if((c= *exprp++)=='n')
				c='\n';
		break;
	case 0:
		c = END;
		--exprp;	
		break;
	case '*':
		c = STAR;
		break;
	case '?':
		c = QUEST;
		break;
	case '+':
		c = PLUS;
		break;
	case '|':
		c = OR;
		break;
	case '.':
		c = ANY;
		break;
	case '(':
		c = LBRA;
		break;
	case ')':
		c = RBRA;
		break;
	case '^':
		c = BOL;
		break;
	case '$':
		c = EOL;
		break;
	case '[':
		c = CCLASS;
		bldcclass();
		break;
	}
	return c;
}

int
nextrec()
{
	if(exprp[0]==0 || (exprp[0]=='\\' && exprp[1]==0))
		regerror("malformed `[]'");
	if(exprp[0] == '\\'){
		exprp++;
		if(*exprp=='n'){
			exprp++;
			return '\n';
		}
		return *exprp++|0x10000;
	}
	return *exprp++;
}

void
bldcclass()
{
	int c1, c2, n, na;
	Rune *classp;

	classp = runemalloc(DCLASS);
	n = 0;
	na = DCLASS;
	
	if(*exprp == '^'){
		classp[n++] = '\n';	
		negateclass = TRUE;
		exprp++;
	}else
		negateclass = FALSE;
	while((c1 = nextrec()) != ']'){
		if(c1 == '-'){
    Error:
			free(classp);
			regerror("malformed `[]'");
		}
		if(n+4 >= na){		
			na += DCLASS;
			classp = runerealloc(classp, na);
		}
		if(*exprp == '-'){
			exprp++;	
			if((c2 = nextrec()) == ']')
				goto Error;
			classp[n+0] = 0xFFFF;
			classp[n+1] = c1;
			classp[n+2] = c2;
			n += 3;
		}else
			classp[n++] = c1;
	}
	classp[n] = 0;
	if(nclass == Nclass){
		Nclass += DCLASS;
		class = realloc(class, Nclass*sizeof(Rune*));
	}
	class[nclass++] = classp;
}

int
classmatch(int classno, int c, int negate)
{
	Rune *p;

	p = class[classno];
	while(*p){
		if(*p == 0xFFFF){
			if(p[1]<=c && c<=p[2])
				return !negate;
			p += 3;
		}else if(*p++ == c)
			return !negate;
	}
	return negate;
}

/*
 * Note optimization in addinst:
 * 	*l must be pending when addinst called; if *l has been looked
 *		at already, the optimization is a bug.
 */
void
addinst(Ilist *l, Inst *inst, Rangeset *sep)
{
	Ilist *p;

	for(p = l; p->inst; p++){
		if(p->inst==inst){
			if((sep)->r[0].q0 < p->se.r[0].q0)
				p->se= *sep;	
			return;	
		}
	}
	p->inst = inst;
	p->se= *sep;
	(p+1)->inst = nil;
}

(int, Rangeset)
rxexecute(Text *t, uint startp, uint eof)
{
	int flag;
	Inst *inst;
	Ilist *tlp;
	uint p;
	int nnl, ntl;
	int c;
	int wrapped;
	int startchar;

	flag = 0;
	p = startp;
	startchar = 0;
	wrapped = 0;
	nnl = 0;
	if(startinst->type<OPERATOR)
		startchar = startinst->type;
	list[0][0].inst = list[1][0].inst = nil;
	sel.r[0].q0 = -1;
	
	for(;;p++){
	doloop:
		if(p>=eof || p>=t->file->nc){
			switch(wrapped++){
			case 0:		
			case 2:
				break;
			case 1:		
				if(sel.r[0].q0>=0 || eof!=Infinity)
					goto Return;
				list[0][0].inst = list[1][0].inst = nil;
				p = 0;
				goto doloop;
			default:
				goto Return;
			}
			c = 0;
		}else{
			if(((wrapped && p>=startp) || sel.r[0].q0>0) && nnl==0)
				break;
			c = t->readc(p);
		}
		
		if(startchar && nnl==0 && c!=startchar)
			continue;
		tl = list[flag];
		nl = list[flag^=1];
		nl->inst = nil;
		ntl = nnl;
		nnl = 0;
		if(sel.r[0].q0<0 && (!wrapped || p<startp || startp==eof)){
			
			if(++ntl >= NLIST)
	Overflow:
				error("regexp list overflow");
			sempty.r[0].q0 = p;
			addinst(tl, startinst, &sempty);
		}
		
		for(tlp = tl; inst = tlp->inst; tlp++){	
	Switchstmt:
			switch(inst->type){
			default:	
				if(inst->type==c){
	Addinst:
					if(++nnl >= NLIST)
						goto Overflow;
					addinst(nl, inst->next, &tlp->se);
				}
				break;
			case LBRA:
				if(inst->subid>=0)
					tlp->se.r[inst->subid].q0 = p;
				inst = inst->next;
				goto Switchstmt;
			case RBRA:
				if(inst->subid>=0)
					tlp->se.r[inst->subid].q1 = p;
				inst = inst->next;
				goto Switchstmt;
			case ANY:
				if(c!='\n')
					goto Addinst;
				break;
			case BOL:
				if(p==0 || t->readc(p-1)=='\n'){
	Step:
					inst = inst->next;
					goto Switchstmt;
				}
				break;
			case EOL:
				if(c == '\n')
					goto Step;
				break;
			case CCLASS:
				if(c>=0 && classmatch(inst->class, c, 0))
					goto Addinst;
				break;
			case NCCLASS:
				if(c>=0 && classmatch(inst->class, c, 1))
					goto Addinst;
				break;
			case OR:
				
				if(++ntl >= NLIST)
					goto Overflow;
				addinst(tlp, inst->right, &tlp->se);
				
				inst = inst->left;
				goto Switchstmt;
			case END:	
				tlp->se.r[0].q1 = p;
				newmatch(&tlp->se);
				break;
			}
		}
	}
    Return:
	return (sel.r[0].q0>=0, sel);
}

void
newmatch(Rangeset *sp)
{
	if(sel.r[0].q0<0 || sp->r[0].q0<sel.r[0].q0 ||
	   (sp->r[0].q0==sel.r[0].q0 && sp->r[0].q1>sel.r[0].q1))
		sel = *sp;
}

(int, Rangeset)
rxbexecute(Text *t, uint startp)
{
	int flag;
	Inst *inst;
	Ilist *tlp;
	int p;
	int nnl, ntl;
	int c;
	int wrapped;
	int startchar;

	flag = 0;
	nnl = 0;
	wrapped = 0;
	p = startp;
	startchar = 0;
	if(bstartinst->type<OPERATOR)
		startchar = bstartinst->type;
	list[0][0].inst = list[1][0].inst = nil;
	sel.r[0].q0= -1;
	
	for(;;--p){
	doloop:
		if(p <= 0){
			switch(wrapped++){
			case 0:		
			case 2:
				break;
			case 1:		
				if(sel.r[0].q0>=0)
					goto Return;
				list[0][0].inst = list[1][0].inst = nil;
				p = t->file->nc;
				goto doloop;
			case 3:
			default:
				goto Return;
			}
			c = 0;
		}else{
			if(((wrapped && p<=startp) || sel.r[0].q0>0) && nnl==0)
				break;
			c = t->readc(p-1);
		}
		
		if(startchar && nnl==0 && c!=startchar)
			continue;
		tl = list[flag];
		nl = list[flag^=1];
		nl->inst = nil;
		ntl = nnl;
		nnl = 0;
		if(sel.r[0].q0<0 && (!wrapped || p>startp)){
			
			if(++ntl >= NLIST)
	Overflow:
				error("regexp list overflow");
			
			sempty.r[0].q0 = -p;
			addinst(tl, bstartinst, &sempty);
		}
		
		for(tlp = tl; inst = tlp->inst; tlp++){	
	Switchstmt:
			switch(inst->type){
			default:	
				if(inst->type == c){
	Addinst:
					if(++nnl >= NLIST)
						goto Overflow;
					addinst(nl, inst->next, &tlp->se);
				}
				break;
			case LBRA:
				if(inst->subid>=0)
					tlp->se.r[inst->subid].q0 = p;
				inst = inst->next;
				goto Switchstmt;
			case RBRA:
				if(inst->subid >= 0)
					tlp->se.r[inst->subid].q1 = p;
				inst = inst->next;
				goto Switchstmt;
			case ANY:
				if(c != '\n')
					goto Addinst;
				break;
			case BOL:
				if(c=='\n' || p==0){
	Step:
					inst = inst->next;
					goto Switchstmt;
				}
				break;
			case EOL:
				if(p<t->file->nc && t->readc(p)=='\n')
					goto Step;
				break;
			case CCLASS:
				if(c>0 && classmatch(inst->class, c, 0))
					goto Addinst;
				break;
			case NCCLASS:
				if(c>0 && classmatch(inst->class, c, 1))
					goto Addinst;
				break;
			case OR:
				
				if(++ntl >= NLIST)
					goto Overflow;
				addinst(tlp, inst->right, &tlp->se);
				
				inst = inst->left;
				goto Switchstmt;
			case END:	
				tlp->se.r[0].q0 = -tlp->se.r[0].q0; 
				tlp->se.r[0].q1 = p;
				bnewmatch(&tlp->se);
				break;
			}
		}
	}
    Return:
	return (sel.r[0].q0>=0, sel);
}

void
bnewmatch(Rangeset *sp)
{
        int  i;

        if(sel.r[0].q0<0 || sp->r[0].q0>sel.r[0].q1 || (sp->r[0].q0==sel.r[0].q1 && sp->r[0].q1<sel.r[0].q0))
                for(i = 0; i<NRange; i++){       
                        sel.r[i].q0 = sp->r[i].q1;
                        sel.r[i].q1 = sp->r[i].q0;
                }
}
