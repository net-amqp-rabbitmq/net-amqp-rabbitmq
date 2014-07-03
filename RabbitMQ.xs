#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "amqp.h"
#include "amqp_tcp_socket.h"
#include "amqp_private.h"

typedef amqp_connection_state_t Net__AMQP__RabbitMQ;

#define int_from_hv(hv,name) \
 do { SV **v; if(NULL != (v = hv_fetch(hv, #name, strlen(#name), 0))) name = SvIV(*v); } while(0)
#define double_from_hv(hv,name) \
 do { SV **v; if(NULL != (v = hv_fetch(hv, #name, strlen(#name), 0))) name = SvNV(*v); } while(0)
#define str_from_hv(hv,name) \
 do { SV **v; if(NULL != (v = hv_fetch(hv, #name, strlen(#name), 0))) name = SvPV_nolen(*v); } while(0)

void die_on_error(pTHX_ int x, amqp_connection_state_t conn, char const *context) {
  /* Handle socket errors */
  if ( x == AMQP_STATUS_CONNECTION_CLOSED || x == AMQP_STATUS_SOCKET_ERROR ) {
      amqp_socket_close( amqp_get_socket( conn ) );
      Perl_croak(aTHX_ "%s failed because AMQP socket connection was closed.", context);
  }
  /* Handle everything else */
  else if (x < 0) {
    Perl_croak(aTHX_ "%s: %s\n", context, strerror(-x));
  }
}

amqp_pool_t hash_pool;

void die_on_amqp_error(pTHX_ amqp_rpc_reply_t x, amqp_connection_state_t conn, char const *context) {
  switch (x.reply_type) {
    case AMQP_RESPONSE_NORMAL:
      return;

    case AMQP_RESPONSE_NONE:
      Perl_croak(aTHX_ "%s: missing RPC reply type!", context);
      break;

    case AMQP_RESPONSE_LIBRARY_EXCEPTION:
      /* If we got a library error saying that there's a socket problem,
         kill the connection and croak. */
      if (
        x.library_error == AMQP_STATUS_CONNECTION_CLOSED
        ||
        x.library_error == AMQP_STATUS_SOCKET_ERROR
      ) {
        amqp_socket_close( amqp_get_socket( conn ) );
        Perl_croak(aTHX_ "%s: failed since AMQP socket connection closed.\n", context);
      }
      /* Otherwise, give a more generic croak. */
      else {
        Perl_croak(aTHX_ "%s: %s\n", context,
                x.library_error ? strerror(x.library_error) : "(end-of-stream)");
      }
      break;

    case AMQP_RESPONSE_SERVER_EXCEPTION:
      switch (x.reply.id) {
        case AMQP_CONNECTION_CLOSE_METHOD: {
          amqp_connection_close_t *m = (amqp_connection_close_t *) x.reply.decoded;
          Perl_croak(aTHX_ "%s: server connection error %d, message: %.*s",
                  context,
                  m->reply_code,
                  (int) m->reply_text.len, (char *) m->reply_text.bytes);
          break;
        }
        case AMQP_CHANNEL_CLOSE_METHOD: {
          amqp_channel_close_t *m = (amqp_channel_close_t *) x.reply.decoded;
          Perl_croak(aTHX_ "%s: server channel error %d, message: %.*s",
                  context,
                  m->reply_code,
                  (int) m->reply_text.len, (char *) m->reply_text.bytes);
          break;
        }
        default:
          Perl_croak(aTHX_ "%s: unknown server error, method id 0x%08X", context, x.reply.id);
          break;
      }
      break;
  }
}

int internal_recv(HV *RETVAL, amqp_connection_state_t conn, int piggyback) {
  amqp_frame_t frame;
  amqp_basic_deliver_t *d;
  amqp_basic_properties_t *p;
  size_t body_target;
  size_t body_received;
  int result;
  int is_utf8_body = 1; // The body is UTF-8 by default

  result = 0;
  while (1) {
    SV *payload;

    if(!piggyback) {
      amqp_maybe_release_buffers(conn);
      result = amqp_simple_wait_frame(conn, &frame);
      if (result != AMQP_STATUS_OK) break;
      if (frame.frame_type == AMQP_FRAME_HEARTBEAT) {
        // Well, let's send the heartbeat frame back, shouldn't we?
        amqp_frame_t hb_resp;
        hb_resp.frame_type = AMQP_FRAME_HEARTBEAT;
        hb_resp.channel = 0;
        amqp_send_frame(conn, &hb_resp);
        continue;
      }
      if (frame.frame_type != AMQP_FRAME_METHOD) continue;
      if (frame.payload.method.id != AMQP_BASIC_DELIVER_METHOD) continue;
      d = (amqp_basic_deliver_t *) frame.payload.method.decoded;
      hv_store(RETVAL, "delivery_tag", strlen("delivery_tag"), newSVpvn((const char *)&d->delivery_tag, sizeof(d->delivery_tag)), 0);
      hv_store(RETVAL, "exchange", strlen("exchange"), newSVpvn(d->exchange.bytes, d->exchange.len), 0);
      hv_store(RETVAL, "consumer_tag", strlen("consumer_tag"), newSVpvn(d->consumer_tag.bytes, d->consumer_tag.len), 0);
      hv_store(RETVAL, "routing_key", strlen("routing_key"), newSVpvn(d->routing_key.bytes, d->routing_key.len), 0);
      piggyback = 0;
    }

    result = amqp_simple_wait_frame(conn, &frame);
    if (frame.frame_type == AMQP_FRAME_HEARTBEAT) {
      amqp_frame_t hb_resp;
      hb_resp.frame_type = AMQP_FRAME_HEARTBEAT;
      hb_resp.channel = 0;
      amqp_send_frame(conn, &hb_resp);
      continue;
    }
    if (result != AMQP_STATUS_OK) break;

    if (frame.frame_type != AMQP_FRAME_HEADER)
      Perl_croak(aTHX_ "Unexpected header %d!", frame.frame_type);

    HV *props;
    props = newHV();
    hv_store(RETVAL, "props", strlen("props"), newRV_noinc((SV *)props), 0);

    p = (amqp_basic_properties_t *) frame.payload.properties.decoded;
    if (p->_flags & AMQP_BASIC_CONTENT_TYPE_FLAG) {
      hv_store(props, "content_type", strlen("content_type"),
               newSVpvn(p->content_type.bytes, p->content_type.len), 0);
    }
    if (p->_flags & AMQP_BASIC_CONTENT_ENCODING_FLAG) {
      hv_store(props, "content_encoding", strlen("content_encoding"),
               newSVpvn(p->content_encoding.bytes, p->content_encoding.len), 0);

      /*
       * Since we could have UTF-8 in our content-encoding, and most people seem like they
       * treat this like the default, we're looking for the presence of content-encoding but
       * the absence of a case-insensitive "UTF-8".
       */
      if (
        strnlen(p->content_encoding.bytes, p->content_encoding.len) > 0
        &&
        (strncasecmp(p->content_encoding.bytes, "UTF-8", p->content_encoding.len) != 0)
      ) {
        is_utf8_body = 0;
      }
    }
    if (p->_flags & AMQP_BASIC_CORRELATION_ID_FLAG) {
      hv_store(props, "correlation_id", strlen("correlation_id"),
               newSVpvn(p->correlation_id.bytes, p->correlation_id.len), 0);
    }
    if (p->_flags & AMQP_BASIC_REPLY_TO_FLAG) {
      hv_store(props, "reply_to", strlen("reply_to"),
               newSVpvn(p->reply_to.bytes, p->reply_to.len), 0);
    }
    if (p->_flags & AMQP_BASIC_EXPIRATION_FLAG) {
      hv_store(props, "expiration", strlen("expiration"),
               newSVpvn(p->expiration.bytes, p->expiration.len), 0);
    }
    if (p->_flags & AMQP_BASIC_MESSAGE_ID_FLAG) {
      hv_store(props, "message_id", strlen("message_id"),
               newSVpvn(p->message_id.bytes, p->message_id.len), 0);
    }
    if (p->_flags & AMQP_BASIC_TYPE_FLAG) {
      hv_store(props, "type", strlen("type"),
               newSVpvn(p->type.bytes, p->type.len), 0);
    }
    if (p->_flags & AMQP_BASIC_USER_ID_FLAG) {
      hv_store(props, "user_id", strlen("user_id"),
               newSVpvn(p->user_id.bytes, p->user_id.len), 0);
    }
    if (p->_flags & AMQP_BASIC_APP_ID_FLAG) {
      hv_store(props, "app_id", strlen("app_id"),
               newSVpvn(p->app_id.bytes, p->app_id.len), 0);
    }
    if (p->_flags & AMQP_BASIC_DELIVERY_MODE_FLAG) {
      hv_store(props, "delivery_mode", strlen("delivery_mode"),
               newSViv(p->delivery_mode), 0);
    }
    if (p->_flags & AMQP_BASIC_PRIORITY_FLAG) {
      hv_store(props, "priority", strlen("priority"),
               newSViv(p->priority), 0);
    }
    if (p->_flags & AMQP_BASIC_TIMESTAMP_FLAG) {
      hv_store(props, "timestamp", strlen("timestamp"),
               newSViv(p->timestamp), 0);
    }

    if (p->_flags & AMQP_BASIC_HEADERS_FLAG) {
      int i;
      SV *val;
      HV *headers = newHV();
      hv_store( props, "headers", strlen("headers"), newRV_noinc((SV *)headers), 0 );

      for( i=0; i < p->headers.num_entries; ++i ) {
        if( p->headers.entries[i].value.kind == AMQP_FIELD_KIND_I32 ) {
          hv_store( headers,
              p->headers.entries[i].key.bytes, p->headers.entries[i].key.len,
              newSViv(p->headers.entries[i].value.value.i32),
              0
          );
        }

        // Handle kind UTF8 and kind BYTES
        else if(
          p->headers.entries[i].value.kind == AMQP_FIELD_KIND_UTF8
          ||
          p->headers.entries[i].value.kind == AMQP_FIELD_KIND_BYTES
        ) {
          SV *hvalue = newSVpvn(
            p->headers.entries[i].value.value.bytes.bytes,
            p->headers.entries[i].value.value.bytes.len
          );

          /* If it's UTF8, set the flag on... */
          if (p->headers.entries[i].value.kind == AMQP_FIELD_KIND_UTF8) {
            SvUTF8_on(hvalue);
          }

          hv_store( headers,
              p->headers.entries[i].key.bytes, p->headers.entries[i].key.len,
              hvalue,
              0
          );
        }
      }
    }

    body_target = frame.payload.properties.body_size;
    body_received = 0;
    payload = newSVpvn("", 0);

    while (body_received < body_target) {
      result = amqp_simple_wait_frame(conn, &frame);
      if (result != AMQP_STATUS_OK) break;

      if (frame.frame_type != AMQP_FRAME_BODY) {
        Perl_croak(aTHX_ "Expected fram body, got %d!", frame.frame_type);
      }

      body_received += frame.payload.body_fragment.len;
      assert(body_received <= body_target);

      sv_catpvn(payload, frame.payload.body_fragment.bytes, frame.payload.body_fragment.len);
    }

    if (body_received != body_target) {
      /* Can only happen when amqp_simple_wait_frame returns <= 0 */
      /* We break here to close the connection */
      Perl_croak(aTHX_ "Short read %llu != %llu", (long long unsigned int)body_received, (long long unsigned int)body_target);
    }

    // Turn on the UTF-8 flag if the body is UTF-8
    if (is_utf8_body) {
      SvUTF8_on(payload);
    }
    
    hv_store(RETVAL, "body", strlen("body"), payload, 0);
    break;
  }
  return result;
}

void hash_to_amqp_table(amqp_connection_state_t conn, HV *hash, amqp_table_t *table) {
  HE   *he;
  char *key;
  SV   *value;
  I32  retlen;
  amqp_table_entry_t *entry;

  amqp_table_entry_t *new_entries = amqp_pool_alloc( &hash_pool, HvKEYS(hash) * sizeof(amqp_table_entry_t) );
  table->entries = new_entries;

  hv_iterinit(hash);
  while (NULL != (he = hv_iternext(hash))) {
    key = hv_iterkey(he, &retlen);
    value = hv_iterval(hash, he);

    if (SvGMAGICAL(value))
      mg_get(value);


    if (SvPOK(value)) {
      entry = &table->entries[table->num_entries];
      table->num_entries++;

      entry->key = amqp_cstring_bytes(key);
      entry->value.kind = AMQP_FIELD_KIND_UTF8;
      entry->value.value.bytes = amqp_cstring_bytes(SvPV_nolen(value));
    } else if (SvIOK(value)) {
      entry = &table->entries[table->num_entries];
      table->num_entries++;

      entry->key = amqp_cstring_bytes(key);
      entry->value.kind = AMQP_FIELD_KIND_I32;
      entry->value.value.i32 = (uint64_t) SvIV(value);
    } else {
      Perl_croak( aTHX_ "Unsupported SvType for hash value: %d", SvTYPE(value) );
    }
  }
}

MODULE = Net::AMQP::RabbitMQ PACKAGE = Net::AMQP::RabbitMQ PREFIX = net_amqp_rabbitmq_

REQUIRE:        1.9505
PROTOTYPES:     DISABLE

int
net_amqp_rabbitmq_connect(conn, hostname, options)
  Net::AMQP::RabbitMQ conn
  char *hostname
  HV *options
  PREINIT:
    amqp_socket_t *sock;
    char *user = "guest";
    char *password = "guest";
    char *vhost = "/";
    int port = 5672;
    int channel_max = 0;
    int frame_max = 131072;
    int heartbeat = 0;
    double timeout = -1;
    struct timeval to;
  CODE:
    str_from_hv(options, user);
    str_from_hv(options, password);
    str_from_hv(options, vhost);
    int_from_hv(options, channel_max);
    int_from_hv(options, frame_max);
    int_from_hv(options, heartbeat);
    int_from_hv(options, port);
    double_from_hv(options, timeout);
    if(timeout >= 0) {
     to.tv_sec = floor(timeout);
     to.tv_usec = 1000000.0 * (timeout - floor(timeout));
    }
    sock = amqp_tcp_socket_new(conn);

    if (!sock) {
      Perl_croak(aTHX_ "error creating TCP socket");
    }

    die_on_error(aTHX_ amqp_socket_open_noblock(sock, hostname, port, (timeout<0)?NULL:&to), conn, "opening TCP socket");

    die_on_amqp_error(aTHX_ amqp_login(conn, vhost, channel_max, frame_max, heartbeat, AMQP_SASL_METHOD_PLAIN, user, password), conn, "Logging in");
    empty_amqp_pool( &hash_pool );
    init_amqp_pool( &hash_pool, 512 );

    RETVAL = 1;
  OUTPUT:
    RETVAL

void
net_amqp_rabbitmq_channel_open(conn, channel)
  Net::AMQP::RabbitMQ conn
  int channel
  CODE:
    amqp_channel_open(conn, channel);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Opening channel");

void
net_amqp_rabbitmq_channel_close(conn, channel)
  Net::AMQP::RabbitMQ conn
  int channel
  CODE:
    die_on_amqp_error(aTHX_ amqp_channel_close(conn, channel, AMQP_REPLY_SUCCESS), conn, "Closing channel");

void
net_amqp_rabbitmq_exchange_declare(conn, channel, exchange, options = NULL, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *exchange
  HV *options
  HV *args
  PREINIT:
    char *exchange_type = "direct";
    int passive = 0;
    int durable = 0;
    amqp_table_t arguments = amqp_empty_table;
  CODE:
    if(options) {
      str_from_hv(options, exchange_type);
      int_from_hv(options, passive);
      int_from_hv(options, durable);
    }
    amqp_exchange_declare(conn, channel, amqp_cstring_bytes(exchange), amqp_cstring_bytes(exchange_type),
                          passive, durable, arguments);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Declaring exchange");

void
net_amqp_rabbitmq_exchange_delete(conn, channel, exchange, options = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *exchange
  HV *options
  PREINIT:
    int if_unused = 1;
  CODE:
    if(options) {
      int_from_hv(options, if_unused);
    }
    amqp_exchange_delete(conn, channel, amqp_cstring_bytes(exchange), if_unused);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Deleting exchange");

void net_amqp_rabbitmq_queue_delete(conn, channel, queuename, options = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  HV *options
  PREINIT:
    int if_unused = 1;
    int if_empty = 1;
  CODE:
    if(options) {
      int_from_hv(options, if_unused);
      int_from_hv(options, if_empty);
    }
    amqp_queue_delete_ok_t *reply = amqp_queue_delete(
            conn,
            channel,
            amqp_cstring_bytes(queuename),
            if_unused,
            if_empty
        );
    if (reply == NULL) {
        die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Deleting queue");
    }
    XPUSHs(sv_2mortal(newSVuv(reply->message_count)));

void
net_amqp_rabbitmq_queue_declare(conn, channel, queuename, options = NULL, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  HV *options
  HV *args
  PREINIT:
    int passive = 0;
    int durable = 0;
    int exclusive = 0;
    int auto_delete = 1;
    amqp_table_t arguments = amqp_empty_table;
    amqp_bytes_t queuename_b = amqp_empty_bytes;
  PPCODE:
    if(queuename && strcmp(queuename, "")) queuename_b = amqp_cstring_bytes(queuename);
    if(options) {
      int_from_hv(options, passive);
      int_from_hv(options, durable);
      int_from_hv(options, exclusive);
      int_from_hv(options, auto_delete);
    }
    if(args)
      hash_to_amqp_table(conn, args, &arguments);
    amqp_queue_declare_ok_t *r = amqp_queue_declare(conn, channel, queuename_b, passive,
                                                    durable, exclusive, auto_delete,
                                                    arguments);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Declaring queue");
    XPUSHs(sv_2mortal(newSVpvn(r->queue.bytes, r->queue.len)));
    if(GIMME_V == G_ARRAY) {
      XPUSHs(sv_2mortal(newSVuv(r->message_count)));
      XPUSHs(sv_2mortal(newSVuv(r->consumer_count)));
    }

void
net_amqp_rabbitmq_queue_bind(conn, channel, queuename, exchange, bindingkey, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  char *exchange
  char *bindingkey
  HV *args
  PREINIT:
    amqp_table_t arguments = amqp_empty_table;
  CODE:
    if(queuename == NULL || exchange == NULL)
      Perl_croak(aTHX_ "queuename and exchange must both be specified");
    if(bindingkey == NULL && args == NULL)
      Perl_croak(aTHX_ "bindingkey or args must be specified");
    if(args)
      hash_to_amqp_table(conn, args, &arguments);
    amqp_queue_bind(conn, channel, amqp_cstring_bytes(queuename),
                    amqp_cstring_bytes(exchange),
                    amqp_cstring_bytes(bindingkey),
                    arguments);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Binding queue");

void
net_amqp_rabbitmq_queue_unbind(conn, channel, queuename, exchange, bindingkey, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  char *exchange
  char *bindingkey
  HV *args
  PREINIT:
    amqp_table_t arguments = amqp_empty_table;
  CODE:
    if(queuename == NULL || exchange == NULL)
      Perl_croak(aTHX_ "queuename and exchange must both be specified");
    if(bindingkey == NULL && args == NULL)
      Perl_croak(aTHX_ "bindingkey or args must be specified");
    if(args)
      hash_to_amqp_table(conn, args, &arguments);
    amqp_queue_unbind(conn, channel, amqp_cstring_bytes(queuename),
                      amqp_cstring_bytes(exchange),
                    amqp_cstring_bytes(bindingkey),
                    arguments);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Unbinding queue");

SV *
net_amqp_rabbitmq_consume(conn, channel, queuename, options = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  HV *options
  PREINIT:
    amqp_basic_consume_ok_t *r;
    char *consumer_tag = NULL;
    int no_local = 0;
    int no_ack = 1;
    int exclusive = 0;
  CODE:
    if(options) {
      str_from_hv(options, consumer_tag);
      int_from_hv(options, no_local);
      int_from_hv(options, no_ack);
      int_from_hv(options, exclusive);
    }
    r = amqp_basic_consume(conn, channel, amqp_cstring_bytes(queuename),
                           consumer_tag ? amqp_cstring_bytes(consumer_tag) : amqp_empty_bytes,
                           no_local, no_ack, exclusive, amqp_empty_table);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Consume queue");
    RETVAL = newSVpvn(r->consumer_tag.bytes, r->consumer_tag.len);
  OUTPUT:
    RETVAL

HV *
net_amqp_rabbitmq_recv(conn)
  Net::AMQP::RabbitMQ conn
  PREINIT:
    amqp_status_enum status = AMQP_STATUS_OK;
  CODE:
    RETVAL = newHV();

    /* We want to detect whether we were disconnected by the remote host during the internal_recv(). */
    status = internal_recv(RETVAL, conn, 0);
    if ( status == AMQP_STATUS_CONNECTION_CLOSED || status == AMQP_STATUS_SOCKET_ERROR ) {
        amqp_socket_close( amqp_get_socket( conn ) );
        Perl_croak(aTHX_ "AMQP socket connection was closed.");
    }
    sv_2mortal((SV*)RETVAL);
  OUTPUT:
    RETVAL

void
net_amqp_rabbitmq_ack(conn, channel, delivery_tag, multiple = 0)
  Net::AMQP::RabbitMQ conn
  int channel
  SV *delivery_tag
  int multiple
  PREINIT:
    STRLEN len;
    uint64_t tag;
    unsigned char *l;
  CODE:
    l = SvPV(delivery_tag, len);
    if(len != sizeof(tag)) Perl_croak(aTHX_ "bad tag");
    memcpy(&tag, l, sizeof(tag));
    die_on_error(aTHX_ amqp_basic_ack(conn, channel, tag, multiple), conn,
                 "ack");


void
net_amqp_rabbitmq_reject(conn, channel, delivery_tag, requeue = 0)
 Net::AMQP::RabbitMQ conn
 int channel
 SV *delivery_tag
 int requeue
 PREINIT:
   STRLEN len;
   uint64_t tag;
   unsigned char *l;
 CODE:
   l = SvPV(delivery_tag, len);
   if(len != sizeof(tag)) Perl_croak(aTHX_ "bad tag");
   memcpy(&tag, l, sizeof(tag));
   die_on_error(aTHX_ amqp_basic_reject(conn, channel, tag, requeue), conn,
                "reject");


void
net_amqp_rabbitmq_purge(conn, channel, queuename)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  CODE:
    amqp_queue_purge(conn, channel, amqp_cstring_bytes(queuename));
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Purging queue");

void
net_amqp_rabbitmq__publish(conn, channel, routing_key, body, options = NULL, props = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  HV *options;
  char *routing_key
  SV *body
  HV *props
  PREINIT:
    SV **v;
    char *exchange = "amq.direct";
    amqp_boolean_t mandatory = 0;
    amqp_boolean_t immediate = 0;
    int rv;
    amqp_bytes_t exchange_b = { 0 };
    amqp_bytes_t routing_key_b;
    amqp_bytes_t body_b;
    struct amqp_basic_properties_t_ properties;
    STRLEN len;
  CODE:
    routing_key_b = amqp_cstring_bytes(routing_key);
    body_b.bytes = SvPV(body, len);
    body_b.len = len;
    if(options) {
      if(NULL != (v = hv_fetch(options, "mandatory", strlen("mandatory"), 0))) mandatory = SvIV(*v) ? 1 : 0;
      if(NULL != (v = hv_fetch(options, "immediate", strlen("immediate"), 0))) immediate = SvIV(*v) ? 1 : 0;
      if(NULL != (v = hv_fetch(options, "exchange", strlen("exchange"), 0))) exchange_b = amqp_cstring_bytes(SvPV_nolen(*v));
    }
    properties.headers = amqp_empty_table;
    properties._flags = 0;
    if (props) {
      if (NULL != (v = hv_fetch(props, "content_type", strlen("content_type"), 0))) {
        properties.content_type     = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_CONTENT_TYPE_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "content_encoding", strlen("content_encoding"), 0))) {
        properties.content_encoding = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_CONTENT_ENCODING_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "correlation_id", strlen("correlation_id"), 0))) {
        properties.correlation_id   =  amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_CORRELATION_ID_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "reply_to", strlen("reply_to"), 0))) {
        properties.reply_to         = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_REPLY_TO_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "expiration", strlen("expiration"), 0))) {
        properties.expiration       = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_EXPIRATION_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "message_id", strlen("message_id"), 0))) {
        properties.message_id       = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_MESSAGE_ID_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "type", strlen("type"), 0))) {
        properties.type             = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_TYPE_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "user_id", strlen("user_id"), 0))) {
        properties.user_id          = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_USER_ID_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "app_id", strlen("app_id"), 0))) {
        properties.app_id           = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_APP_ID_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "delivery_mode", strlen("delivery_mode"), 0))) {
        properties.delivery_mode    = (uint8_t) SvIV(*v);
        properties._flags |= AMQP_BASIC_DELIVERY_MODE_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "priority", strlen("priority"), 0))) {
        properties.priority         = (uint8_t) SvIV(*v);
        properties._flags |= AMQP_BASIC_PRIORITY_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "timestamp", strlen("timestamp"), 0))) {
        properties.timestamp        = (uint64_t) SvIV(*v);
        properties._flags |= AMQP_BASIC_TIMESTAMP_FLAG;
      }
      if (NULL != (v = hv_fetch(props, "headers", strlen("headers"), 0))) {
        hash_to_amqp_table(conn, (HV *)SvRV(*v), &properties.headers);
        properties._flags |= AMQP_BASIC_HEADERS_FLAG;
      }
    }
    rv = amqp_basic_publish(conn, channel, exchange_b, routing_key_b, mandatory, immediate, &properties, body_b);

    /* If the connection failed, blast the file descriptor! */
    if ( rv == AMQP_STATUS_CONNECTION_CLOSED || rv == AMQP_STATUS_SOCKET_ERROR ) {
        amqp_socket_close( amqp_get_socket( conn ) );
        Perl_croak(aTHX_ "Publish failed because AMQP socket connection was closed.");
    }

    /* Otherwise, just croak */
    if ( rv != AMQP_STATUS_OK ) {
        Perl_croak( aTHX_ "Publish failed, error code %d", rv);
    }

SV *
net_amqp_rabbitmq_get(conn, channel, queuename, options = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  HV *options
  PREINIT:
    amqp_rpc_reply_t r;
    int no_ack = 1;
  CODE:
    if(options)
      int_from_hv(options, no_ack);
    amqp_maybe_release_buffers(conn);
    r = amqp_basic_get(conn, channel, queuename ? amqp_cstring_bytes(queuename) : amqp_empty_bytes, no_ack);
    die_on_amqp_error(aTHX_ r, conn, "basic_get");
    if(r.reply.id == AMQP_BASIC_GET_OK_METHOD) {
      HV *hv;
      amqp_basic_get_ok_t *ok = (amqp_basic_get_ok_t *)r.reply.decoded;
      hv = newHV();
      hv_store(hv, "delivery_tag", strlen("delivery_tag"), newSVpvn((const char *)&ok->delivery_tag, sizeof(ok->delivery_tag)), 0);
      hv_store(hv, "redelivered", strlen("redelivered"), newSViv(ok->redelivered), 0);
      hv_store(hv, "exchange", strlen("exchange"), newSVpvn(ok->exchange.bytes, ok->exchange.len), 0);
      hv_store(hv, "routing_key", strlen("routing_key"), newSVpvn(ok->routing_key.bytes, ok->routing_key.len), 0);
      hv_store(hv, "message_count", strlen("message_count"), newSViv(ok->message_count), 0);
      if(amqp_data_in_buffer(conn)) {
        int rv;
        rv = internal_recv(hv, conn, 1);
        if ( rv == AMQP_STATUS_CONNECTION_CLOSED || rv == AMQP_STATUS_SOCKET_ERROR ) {
          amqp_socket_close( amqp_get_socket( conn ) );
          Perl_croak(aTHX_ "Failed to get(), AMQP socket connection was closed.");
        }
        else if(rv != AMQP_STATUS_OK) {
          Perl_croak(aTHX_ "Bad frame read.");
        }
      }
      RETVAL = (SV *)newRV_noinc((SV *)hv);
    }
    else {
      RETVAL = &PL_sv_undef;
    }
  OUTPUT:
    RETVAL

int
net_amqp_rabbitmq_get_channel_max(conn)
  Net::AMQP::RabbitMQ conn
  CODE:
    RETVAL = amqp_get_channel_max(conn);
  OUTPUT:
    RETVAL

SV*
net_amqp_rabbitmq_is_connected(conn)
  Net::AMQP::RabbitMQ conn
  CODE:
    if (
      amqp_get_socket( conn ) != NULL
      &&
      amqp_get_sockfd( conn ) > -1
    ) {
      RETVAL = newSViv(1);
    }
    else {
      // We don't have a connection, we're still here.
      RETVAL = &PL_sv_undef;
    }
  OUTPUT:
    RETVAL

void
net_amqp_rabbitmq_disconnect(conn)
  Net::AMQP::RabbitMQ conn
  PREINIT:
    int sockfd;
  CODE:
    if ( conn->socket != NULL ) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        amqp_socket_close( amqp_get_socket( conn ) );
    }

Net::AMQP::RabbitMQ
net_amqp_rabbitmq_new(clazz)
  char *clazz
  CODE:
    RETVAL = amqp_new_connection();
  OUTPUT:
    RETVAL

void
net_amqp_rabbitmq_DESTROY(conn)
  Net::AMQP::RabbitMQ conn
  CODE:
    if ( conn->socket != NULL ) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
    }
    empty_amqp_pool( &hash_pool );
    amqp_destroy_connection(conn);

void
net_amqp_rabbitmq_heartbeat(conn)
  Net::AMQP::RabbitMQ conn
  PREINIT:
  amqp_frame_t f;
  CODE:
    f.frame_type = AMQP_FRAME_HEARTBEAT;
    f.channel = 0;
    amqp_send_frame(conn, &f);

void
net_amqp_rabbitmq_tx_select(conn, channel, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  HV *args
  CODE:
    amqp_tx_select(conn, channel);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Selecting transaction");

void
net_amqp_rabbitmq_tx_commit(conn, channel, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  HV *args
  PREINIT:
    amqp_pool_t *channel_pool;
  CODE:
    amqp_tx_commit(conn, channel);
    channel_pool = amqp_get_or_create_channel_pool(conn, channel);
    empty_amqp_pool( channel_pool );

    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Commiting transaction");

void
net_amqp_rabbitmq_tx_rollback(conn, channel, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  HV *args
  CODE:
    amqp_tx_rollback(conn, channel);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Rolling Back transaction");

void
net_amqp_rabbitmq_basic_qos(conn, channel, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  HV *args
  PREINIT:
    SV **v;
    uint32_t prefetch_size = 0;
    uint16_t prefetch_count = 0;
    amqp_boolean_t global = 0;
  CODE:
    if(args) {
      if(NULL != (v = hv_fetch(args, "prefetch_size", strlen("prefetch_size"), 0))) prefetch_size = SvIV(*v);
      if(NULL != (v = hv_fetch(args, "prefetch_count", strlen("prefetch_count"), 0))) prefetch_count = SvIV(*v);
      if(NULL != (v = hv_fetch(args, "global", strlen("global"), 0))) global = SvIV(*v) ? 1 : 0;
    }
    amqp_basic_qos(conn, channel, 
                   prefetch_size, prefetch_count, global);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Basic QoS");
