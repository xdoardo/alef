
float
ALEF_rcvflt(Chan *c)
{
	Chan *n;
	Task *t;
	float ret;
	Msgbuf *b;

	c->rcv.lock();
	c->lock();
	if(c->qh) {
		b = c->qh;
		ret = b->f;
		c->qh = b->next;
		b->next = c->free;
		c->free = b;
		c->unlock();
		if(b->next == nil)
			c->br.Wakeup();
		c->rcv.unlock();
		return ret;
	}
	if(c->sva) {
		ret = *(float*)(c->sva);
		c->sva = nil;
		c->unlock();
		c->rcv.unlock();
		c->sndr.Wakeup();
		return ret;
	}
	c->rva = &ret;
	c->unlock();
	t = c->selt;
	if(t != nil && c->seltst != 0) {
		n = t->slist;
		if(n != nil)
			n->selp = 1;
		t->Wakeup();
	}
	c->rcvr.Sleep(&c->rva, 0);
	c->rcv.unlock();
	return ret;
}
