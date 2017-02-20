#include <stdlib.h>
#include <memory.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <string.h>
#include "vpi_user.h"

#define printf vpi_printf

void fatal_error(char *msg) {
  fprintf(stderr, "FATAL ERROR: %s\n", msg);
  vpi_control(vpiFinish);
  exit(-1);
}

void fatal_error_(int errno, char *msg) {
  fprintf(stderr, "FATAL ERROR: [%i] %s\n", errno, msg);
  vpi_control(vpiFinish);
  exit(-1);
}

static int imax(int a, int b) {
  if (a>b) return a;
  else return b;
}

///////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////

// nets.  initially collected in a linked list, then flattened
// into an array.  stores the net name, handle (wire or reg), size,
// and a pointer into a vecval buffer.
typedef struct _net {
  int width, words;
  char *name;
  vpiHandle handle;
  struct _net *next;
} net;

// buffer for collecting network data
typedef struct _mbuf {
  char *data;
  int size, bytes;
} mbuf;

// main simulation state structure
typedef struct _state {
  // socket
  int fd;
  // number of I/O nets
  int num_nets;
  // array of nets
  net *nets;
  // vpi vecval array for all nets
  p_vpi_vecval vdata;
  // buffer for sending/recv'ing net data
  int32_t *pdata;
  mbuf mbuf;
} state;

enum {
  FINISH = 0,
  RUN = 1
};

///////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////

static char *net_addr = "localhost";
static int net_port = 10101;

int create_client(char *server, int port) {
  int fd;
  struct hostent *he;
  struct sockaddr_in saddr;

  fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) goto error;
  
  he = gethostbyname(server);
  if (NULL == he || NULL == he->h_addr) 
    goto error_close_sock;

  saddr.sin_family = AF_INET;
  bcopy(he->h_addr, &(saddr.sin_addr.s_addr), he->h_length);
  saddr.sin_port = htons(port);

  if (connect(fd, (struct sockaddr *) &saddr, sizeof(saddr)) < 0) 
    goto error_close_sock;

  return fd;
  
error_close_sock:
  close(fd);
error:
  return -1;
}

///////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////

int mbuf_init(mbuf *m) {
  m->data = calloc(1024, 1);
  if (NULL == m->data) return -1;
  m->size = 1024;
  m->bytes = 0;
  return 0;
}

void mbuf_destroy(mbuf *m) {
  free(m->data);
  m->size = 0;
  m->bytes = 0;
}

void mbuf_reset(mbuf *m) {
  m->bytes = 0;
}

int mbuf_maybe_grow(mbuf *m, int n) {
  if ((m->bytes + n) > m->size) {
    char *tmp = m->data;
    int oldsize = m->size;
    int newsize = imax(m->size+1024, m->bytes+n);
    m->data = calloc(newsize, 1);
    if (NULL == m->data) return -1;
    m->size = newsize;
    memcpy(m->data, tmp, oldsize);
  }
  return 0;
}

int mbuf_add_int32(mbuf *m, int32_t v) {
  if (mbuf_maybe_grow(m, 4) < 0) return -1;
  *((int32_t*) (m->data + m->bytes)) = v;
  m->bytes += 4;
  return 0;
}

int mbuf_add_string(mbuf *m, char *s) {
  int len = strlen(s);
  mbuf_add_int32(m, len);
  if (mbuf_maybe_grow(m, len) < 0) return -1;
  memcpy(m->data + m->bytes, s, len); 
  m->bytes += len;
  return 0;
}

int mbuf_add_int32_array(mbuf *m, int32_t *v, int len) {
  while (len-- > 0) 
    if (mbuf_add_int32(m, *v++) < 0) return -1;
  return 0;
}

int send_bytes(int fd, char *buf, int bytes) {
  //printf("[C] send_bytes %i\n", bytes);
  //for (int i=0; i<bytes; i++) printf("%.2x ", buf[i]); printf("\n");
  if (0 == bytes) return 0;
  else {
    int len = write(fd, buf, bytes);
    if (len < 0) return -1;
    else {
      bytes -= len;
      if (bytes) return send_bytes(fd, buf + len, bytes);
      else return 0; //ok!
    }
  }
}

int recv_bytes(int fd, char *buf, int bytes) {
  //printf("[C] recv_bytes %i\n", bytes);
  if (0 == bytes) return 0;
  else {
    int len = read(fd, buf, bytes);
    if (len <= 0) return -1;
    else {
      bytes -= len;
      if (bytes > 0) return recv_bytes(fd, buf + len, bytes);
      else return 0;
    }
  }
}

int send_string(state *s, char *p) {
  mbuf_reset(&s->mbuf);
  if (mbuf_add_string(&s->mbuf, p) < 0) return -1;
  //printf("[C] send_string %i\n", s->mbuf.bytes);
  if (send_bytes(s->fd, s->mbuf.data, s->mbuf.bytes) < 0) return -1;
  //printf("[C] send_string ok\n", s->mbuf.bytes);
  return 0;
}

int recv_int32(state *s, int32_t *v) {
  if (recv_bytes(s->fd, (char*) v, sizeof(int32_t)) < 0) return -1;
  return 0;
}

int recv_int64(state *s, int64_t *v) {
  if (recv_bytes(s->fd, (char*) v, sizeof(int64_t)) < 0) return -1;
  return 0;
}

int recv_string(state *s, char **p) {
  int32_t len;
  if (recv_int32(s, &len) < 0) return -1;
  
  mbuf_reset(&s->mbuf);
  if (mbuf_maybe_grow(&s->mbuf, len+1) < 0) return -2;
  if (recv_bytes(s->fd, s->mbuf.data, len) < 0) return -3;
  s->mbuf.data[len] = 0;
  *p = strdup(s->mbuf.data);
  return 0;
}

int recv_int32_array(state *s, int32_t *v, int len) {
  if (recv_bytes(s->fd, (char*) v, sizeof(int32_t)*len) < 0) return -1;
  return 0;
}

///////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////

s_vpi_time tzero, tone;

// fold (iterate) over objects within the given handle, calling the user function
void *fold(vpiHandle handle, int flag, void *(*f)(void*,vpiHandle), void *arg) {
  vpiHandle iter = vpi_iterate(flag, handle);
  if (NULL == iter) return arg;
  else {
    vpiHandle h = NULL;
    do {
      h = vpi_scan(iter);
      if (NULL == h) break;
      arg = f(arg, h);
    } while (1);
    return arg;
  }
}

// initialize a s_vpi_time structure from an 64 bit int
void set_time(p_vpi_time t, int64_t time) {
  t->type = vpiSimTime;
  t->low = (int32_t) time;
  t->high = (int32_t) (time >> 32);
}

// extract a 64 bit time from a s_vpi_time structure
int64_t get_time(p_vpi_time t) {
  return ((int64_t) t->low) | (((int64_t) t->high) << 32);
}

// allocate a net structure
net *alloc_net(int width, char *name, vpiHandle handle) {
  net *n = calloc(1, sizeof(net));
  if (NULL == n) fatal_error("couldn't allocate net");
  n->width = width;
  n->words = (width+31)/32;
  n->name = (NULL != name) ? strdup(name) : NULL;
  n->handle = handle;
  n->next = NULL;
  return n;
}

// free list of nets (but not the carried data)
void free_list_nets(net *n) {
  if (NULL != n) {
    free_list_nets(n->next);
    free(n);
  }
}

// count number of nets in list
int num_nets(net *n) {
  if (NULL == n) return 0;
  else return 1 + num_nets(n->next);
}

// convert list to array of nets
net *array_of_list_nets(net *n) {
  int cnt = num_nets(n), i=0;
  if (0 != cnt) {
    net *a = calloc(cnt, sizeof(net));
    if (NULL == a) fatal_error("couldn't allocate net array");
    for (i=0; i<cnt; i++) {
      a[i] = *n;
      n = n->next;
    }
    return a;
  } else 
    return NULL;
}

// collect nets into a list
void *iter_net_cb(void *arg, vpiHandle h) {
  char *name = vpi_get_str(vpiName, h);
  int width = vpi_get(vpiSize, h);
  net *n = alloc_net(width, name, h);
  n->next = (net *) arg;
  return n;
}

// collect all write and reg nets
void *iter_mod_nets_cb(void *arg, vpiHandle mod) {
  //char *name = vpi_get_str(vpiName, mod);
  net *n = NULL;
  n = fold(mod, vpiNet, iter_net_cb, n);
  n = fold(mod, vpiReg, iter_net_cb, n);
  return n;
}

// free state structure
int free_state(struct t_cb_data *cb) {
  state *s = (state *) cb->user_data;
  //printf("free_state\n"); 
  if (s) {
    int i;
    if (s->fd >= 0) close(s->fd);
    if (s->nets) {
      for (i=0; i<s->num_nets; i++) 
        if (NULL != s->nets[i].name) free(s->nets[i].name);
      free(s->nets);
    }
    if (s->vdata) free(s->vdata);
    if (s->pdata) free(s->pdata);
    free(s);
  }
  return 0;
}

// (network) buffer for passing net data to / from the simulation
void alloc_data(state *s) {
  int words = s->num_nets, pwords, i;
  for (i=0; i<s->num_nets; i++) {
    words = imax(words, s->nets[i].words);
  }
  // max vec length + header, or max nets + 1
  pwords = imax(2 + words, 1 + s->num_nets);
  s->pdata = calloc(pwords, sizeof(uint32_t));
  if (NULL == s->pdata) fatal_error("couldn't allocate pdata array");
  s->vdata = calloc(words, sizeof(s_vpi_vecval));
  if (NULL == s->vdata) fatal_error("couldn't allocate vdata array");
}

int send_net_info(state *s, int idx) {
  if (mbuf_add_int32(&s->mbuf, idx) < 0) return -1;
  if (idx < 0) return 0;
  if (mbuf_add_string(&s->mbuf, s->nets[idx].name) < 0) return -1;
  if (mbuf_add_int32(&s->mbuf, s->nets[idx].width) < 0) return -1;
  return 0;
}

int send_nets_info(state *s) {
  mbuf_reset(&s->mbuf);
  for (int i=0; i<s->num_nets; i++) {
    if (send_net_info(s, i) < 0) return -1;
  }
  if (send_net_info(s, -1) < 0) return -1;
  if (send_bytes(s->fd, s->mbuf.data, s->mbuf.bytes) < 0) return -1;
  return 0;
}

// iterate over all nets in a module, then construct the state
// structure
//
// XXX you can possibly have multiple top-level modules.  we should
// only pick the 'correct' one.
int iter_mod_nets(state *s) {
  net *n = fold(NULL, vpiModule, iter_mod_nets_cb, NULL);
  //printf("iter_mod_nets\n"); vpi_flush();
  s->num_nets = num_nets(n);
  s->nets = array_of_list_nets(n);
  alloc_data(s);
  free_list_nets(n);
  // transmit net info 
  if (send_nets_info(s) < 0) fatal_error("couldn't send net info\n");
  return 0;
}

// query the simulator for the value of a net
void get_net_value(state *s, int net_idx) {
  s_vpi_value v;
  v.format = vpiVectorVal;
  vpi_get_value(s->nets[net_idx].handle, &v);
  for (int i=0; i<s->nets[net_idx].words; i++) 
    s->vdata[i] = v.value.vector[i];
}

// write a net value into the simulator
void set_net_value(state *s, int net_idx) {
  s_vpi_value v;
  v.format = vpiVectorVal;
  v.value.vector = s->vdata;
  vpi_put_value(s->nets[net_idx].handle, &v, &tzero, vpiNoDelay);
}

// register a callback
vpiHandle register_cb(p_cb_data d, int reason, p_vpi_time time, PLI_INT32 (*cb)(struct t_cb_data*), state *s) {
  d->reason = reason;
  d->cb_rtn = cb;
  d->obj = NULL;
  d->time = time;
  d->value = NULL;
  d->index = 0;
  d->user_data = (void *) s;
  return vpi_register_cb(d);
}

///////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////
s_cb_data cb_run, cb_init, cb_destroy;

int run_cosim(struct t_cb_data *cb) {
  state *s = (state *) cb->user_data;

  int32_t control;
  int64_t delta;
  int32_t n_gets;
  int32_t n_sets;

  //printf("[C] awaiting control message\n"); vpi_flush();

  if (recv_int32(s, &control) < 0) return -1;
  if (control == FINISH) {
    //printf("finish\n");
    vpi_control(vpiFinish);
    exit(0);
  } else if (control == RUN) {
    int i, j;
    s_vpi_time time;

    time.type = vpiSimTime;
    vpi_get_time(NULL, &time);

    //printf("run [%li]\n", get_time(&time));

    if (recv_int64(s, &delta) < 0) goto error;
    if (recv_int32(s, &n_sets) < 0) goto error;
    if (recv_int32(s, &n_gets) < 0) goto error;
 
    //printf("sets=%i gets=%i delta=%lx\n", n_sets, n_gets, delta);

    // sets
    for (i=0; i<n_sets; i++) {
      int32_t idx, words;
      recv_int32(s, &idx);
      //printf("SET net idx=%i\n", idx);
      if (idx < 0 || idx >= s->num_nets) fatal_error("bad get net index");
      words = s->nets[idx].words;
      recv_int32_array(s, s->pdata, words);
      for (j=0; j<words; j++) {
        //printf("%.8x\n", s->pdata[j]);
        s->vdata[j].aval = s->pdata[j];
        s->vdata[j].bval = 0;
      }
      set_net_value(s, idx);
    }

    // gets
    mbuf_reset(&s->mbuf);
    for (i=0; i<n_gets; i++) {
      int idx, words;
      recv_int32(s, &idx);
      //printf("GET net idx=%i\n", idx);
      if (idx < 0 || idx >= s->num_nets) fatal_error("bad put net index");
      words = s->nets[idx].words;
      mbuf_add_int32(&s->mbuf, words);
      get_net_value(s, idx);
      for (j=0; j<words; j++) {
        //printf("%.8x %.8x\n", s->vdata[j].aval, s->vdata[j].bval);
        s->pdata[j] = s->vdata[j].aval & (~ s->vdata[j].bval); // X/Z to 0
      }
      if (mbuf_add_int32_array(&s->mbuf, s->pdata, words) < 0) goto error;
    }
    if (send_bytes(s->fd, s->mbuf.data, s->mbuf.bytes) < 0) goto error;
    set_time(&time, delta);
    register_cb(&cb_run, cbAfterDelay, &time, run_cosim, s);
  } else {
    fatal_error("bad control message");
  }

  vpi_flush();
  return 0;

error:
  fatal_error("an error occured during the simulation step\n");
  vpi_flush();
  return -1;
}

///////////////////////////////////////////////////////////////////////
//
///////////////////////////////////////////////////////////////////////

int init_vpi(struct t_cb_data *cb) {
  int errno=0;
  char *hello = NULL;
  // create simulation state
  state *s = calloc(1, sizeof(state));
  if (NULL == s) fatal_error("failed to create simulation state");
  // initialize mbuf
  if (mbuf_init(&s->mbuf) < 0) fatal_error("couldnt create mbuf");
  // initialize client socket
  s->fd = create_client(net_addr, net_port);
  if (s->fd < 0) fatal_error("failed to open socket");
  // send/recv init messages
  if (send_string(s, "hello hardcaml") < 0) fatal_error("couldn't send startup message");
  //printf("[C] sent hello\n"); vpi_flush();
  if ((errno=recv_string(s, &hello)) < 0) fatal_error_(errno, "didnt get hello back from hardcaml");
  if (hello == NULL || (0 != strcmp(hello, "hello verilog")))
    fatal_error("got bad hello from hardcaml");
  //printf("[C] getting ready to start\n"); vpi_flush();
  // time = 0 constant
  set_time(&tzero, 0L);
  set_time(&tone, 1L);
  // get net data at start of simulation
  iter_mod_nets(s);
  // free state structure at end of simulation
  register_cb(&cb_destroy, cbEndOfSimulation, NULL, free_state, s);
  // mesaage passing
  register_cb(&cb_run, cbAfterDelay, &tzero, run_cosim, s);

  //printf("[C] registered stuff\n"); vpi_flush();

  return 0;
}

void init_vpi_startup(void) {
#if 1
  register_cb(&cb_init, cbStartOfSimulation, NULL, init_vpi, NULL);
#else
  init_vpi(NULL);
#endif
}

void (*vlog_startup_routines[])() = {
  init_vpi_startup,
  0
};


