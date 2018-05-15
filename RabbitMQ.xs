#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <float.h>
#include <math.h>

/* perl -MDevel::PPPort -e'Devel::PPPort::WriteFile();' */
/* perl ppport.h --compat-version=5.8.0 --cplusplus RabbitMQ.xs */
#define NEED_newSVpvn_flags
#include "ppport.h"

/* ppport.h knows about MUTABLE_PTR and MUTABLE_SV, but not these?! */
#ifndef MUTABLE_AV
#  define MUTABLE_AV(p) ((AV*)MUTABLE_PTR(p))
#endif
#ifndef MUTABLE_HV
#  define MUTABLE_HV(p) ((HV*)MUTABLE_PTR(p))
#endif

#include "amqp.h"
#include "amqp_tcp_socket.h"
#include "amqp_ssl_socket.h"
/* For struct timeval */
#include "amqp_time.h"

/* This is for the Math::UInt64 integration */
#include "perl_math_int64.h"

/* perl Makefile.PL; make CCFLAGS=-DDEBUG */
#if DEBUG
 #define __DEBUG__(X)  X
#else
 #define __DEBUG__(X) /* NOOP */
#endif

typedef amqp_connection_state_t Net__AMQP__RabbitMQ;

#define AMQP_STATUS_UNKNOWN_TYPE 0x500

#ifdef USE_LONG_DOUBLE
    /* stolen from Cpanel::JSON::XS
     * so we don't mess up double => long double for perls with -Duselongdouble */
#if defined(_AIX) && (!defined(HAS_LONG_DOUBLE) || AIX_WORKAROUND)
#define HAVE_NO_POWL
#endif

    #ifdef HAVE_NO_POWL
        /* Ulisse Monari: this is a patch for AIX 5.3, perl 5.8.8 without HAS_LONG_DOUBLE
          There Perl_pow maps to pow(...) - NOT TO powl(...), core dumps at Perl_pow(...)
          Base code is from http://bytes.com/topic/c/answers/748317-replacement-pow-function
          This is my change to fs_pow that goes into libc/libm for calling fmod/exp/log.
          NEED TO MODIFY Makefile, after perl Makefile.PL by adding "-lm" onto the LDDLFLAGS line */
        static double fs_powEx(double x, double y)
        {
            double p = 0;

            if (0 > x && fmod(y, 1) == 0) {
                if (fmod(y, 2) == 0) {
                    p =  exp(log(-x) * y);
                } else {
                    p = -exp(log(-x) * y);
                }
            } else {
                if (x != 0 || 0 >= y) {
                    p =  exp(log( x) * y);
                }
            }
            return p;
        }

        /* powf() unfortunately is not accurate enough */
        const NV DOUBLE_POW = fs_powEx(10., DBL_DIG );
    #else
        const NV DOUBLE_POW = Perl_pow(10., DBL_DIG );
    #endif
#endif


/* This is a place to put some stuff that we convert from perl,
   it's transient and we recycle it as soon as it's finished being used
   which means we keep memory we've used with the aim of reusing it */
/* temp_memory_pool is ugly and suffers from code smell */
static amqp_pool_t temp_memory_pool;

/* Parallels amqp_maybe_release_buffers */
static void maybe_release_buffers(amqp_connection_state_t state) {
  if (amqp_release_buffers_ok(state)) {
    amqp_release_buffers(state);
    recycle_amqp_pool(&temp_memory_pool);
  }
}

#define int_from_hv(hv,name) \
 do { SV **v; if(NULL != (v = hv_fetchs(hv, #name, 0))) name = SvIV(*v); } while(0)
#define double_from_hv(hv,name) \
 do { SV **v; if(NULL != (v = hv_fetchs(hv, #name, 0))) name = SvNV(*v); } while(0)
#define str_from_hv(hv,name) \
 do { SV **v; if(NULL != (v = hv_fetchs(hv, #name, 0))) name = SvPV_nolen(*v); } while(0)
#define has_valid_connection(conn) \
 ( amqp_get_socket( conn ) != NULL && amqp_get_sockfd( conn ) > -1 )
#define assert_amqp_connected(conn) \
 do { \
  if ( ! has_valid_connection(conn) ) { \
    Perl_croak(aTHX_ "AMQP socket not connected"); \
  } \
 } while(0)

void hash_to_amqp_table(HV *hash, amqp_table_t *table, short force_utf8);
void array_to_amqp_array(AV *perl_array, amqp_array_t *mq_array, short force_utf8);
SV*  mq_array_to_arrayref(amqp_array_t *array);
SV*  mq_table_to_hashref(amqp_table_t *table);

void die_on_error(pTHX_ int x, amqp_connection_state_t conn, char const *context) {
  /* Handle socket errors */
  if ( x == AMQP_STATUS_CONNECTION_CLOSED || x == AMQP_STATUS_SOCKET_ERROR ) {
      amqp_socket_close( amqp_get_socket( conn ) );
      Perl_croak(aTHX_ "%s failed because AMQP socket connection was closed.", context);
  }
  /* Handle everything else */
  else if (x < 0) {
    Perl_croak(aTHX_ "%s: %s\n", context, amqp_error_string2(x));
  }
}

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
                  (!x.library_error) ? "(end-of-stream)" :
                  (x.library_error == AMQP_STATUS_UNKNOWN_TYPE) ? "unknown AMQP type id" :
                  amqp_error_string2(x.library_error));
      }
      break;

    case AMQP_RESPONSE_SERVER_EXCEPTION:
      switch (x.reply.id) {
        case AMQP_CONNECTION_CLOSE_METHOD:
          {
            amqp_connection_close_ok_t req;
            req.dummy = '\0';
            /* res = */ amqp_send_method(conn, 0, AMQP_CONNECTION_CLOSE_OK_METHOD, &req);
          }
          amqp_set_socket(conn, NULL);
          {
            amqp_connection_close_t *m = (amqp_connection_close_t *) x.reply.decoded;
            Perl_croak(aTHX_ "%s: server connection error %d, message: %.*s",
                    context,
                    m->reply_code,
                    (int) m->reply_text.len, (char *) m->reply_text.bytes);
          }
          break;

        case AMQP_CHANNEL_CLOSE_METHOD:
          /* We don't know what channel provoked this error!
             This information should be in amqp_rpc_reply_t,	 but it isn't.
          {
            amqp_channel_close_ok_t req;
            req.dummy = '\0';
            / * res = * / amqp_send_method(conn, channel, AMQP_CHANNEL_CLOSE_OK_METHOD, &req);
          }
          */
          /* Only the channel should be invalidated, but we have no means of doing so! */
          /* Even if we knew which channel we needed to invalidate! */
          amqp_set_socket(conn, NULL);
          {
            amqp_channel_close_t *m = (amqp_channel_close_t *) x.reply.decoded;
            Perl_croak(aTHX_ "%s: server channel error %d, message: %.*s",
                    context,
                    m->reply_code,
                    (int) m->reply_text.len, (char *) m->reply_text.bytes);
          }
          break;

        default:
          Perl_croak(aTHX_ "%s: unknown server error, method id 0x%08X", context, x.reply.id);
          break;
      }
      break;
  }
}

/*
 * amqp_kind_for_sv(SV**)
 * Note: We could handle more types here... but we're trying to take Perl and go to
 *       C. We don't really need to handle much more than this from what I can tell.
 */
amqp_field_value_kind_t amqp_kind_for_sv(SV** perl_value, short force_utf8) {

  switch (SvTYPE( *perl_value ))
  {
    // Integer types (and references beyond 5.10)
    case SVt_IV:
      // References
      if ( SvROK( *perl_value ) ) {
        // Array Reference
        if ( SvTYPE( SvRV( *perl_value ) ) == SVt_PVAV ) {
          return AMQP_FIELD_KIND_ARRAY;
        }

        // Hash Reference
        if ( SvTYPE( SvRV( *perl_value ) ) == SVt_PVHV ) {
          return AMQP_FIELD_KIND_TABLE;
        }
        Perl_croak(
          aTHX_ "Unsupported Perl Reference Type: %d",
          SvTYPE( SvRV( *perl_value ) )
        );
      }

      // Regular integers
      // In the event that it could be unsigned
      if ( SvUOK( *perl_value ) ) {
        return AMQP_FIELD_KIND_U64;
      }
      return AMQP_FIELD_KIND_I64;

    // Numeric type
    case SVt_NV:
      return AMQP_FIELD_KIND_F64;

    // String (handle types which are upgraded to handle IV/UV/NV as well as PV)
    case SVt_PVIV:
      if ( SvI64OK( *perl_value ) ) {
        return AMQP_FIELD_KIND_I64;
      }
      if ( SvU64OK( *perl_value ) ) {
        return AMQP_FIELD_KIND_U64;
      }
      // It could be a PV or an IV/UV!
      if ( SvIOK( *perl_value ) ) {
        if ( SvUOK( *perl_value ) ) {
          return AMQP_FIELD_KIND_U64;
        }
        return AMQP_FIELD_KIND_I64;
      }

    case SVt_PVNV:
      // It could be a PV or an NV
      if ( SvNOK( *perl_value ) ) {
        return AMQP_FIELD_KIND_F64;
      }

    case SVt_PV:
      // UTF-8?
      if ( force_utf8 || SvUTF8( *perl_value ) ) {
        return AMQP_FIELD_KIND_UTF8;
      }
      return AMQP_FIELD_KIND_BYTES;

    case SVt_PVMG:
      if ( SvPOK( *perl_value ) || SvPOKp( *perl_value ) ) {
        if ( force_utf8 || SvUTF8( *perl_value ) ) {
            return AMQP_FIELD_KIND_UTF8;
        }
        return AMQP_FIELD_KIND_BYTES;
      }
      if ( SvIOK( *perl_value ) || SvIOKp( *perl_value ) ) {
        if ( SvUOK( *perl_value ) ) {
          return AMQP_FIELD_KIND_U64;
        }
        return AMQP_FIELD_KIND_I64;
      }
      if ( SvNOK( *perl_value ) || SvNOKp( *perl_value ) )  {
        return AMQP_FIELD_KIND_F64;
      }

    default:
      if ( SvROK( *perl_value ) ) {
        // Array Reference
        if ( SvTYPE( SvRV( *perl_value ) ) == SVt_PVAV ) {
          return AMQP_FIELD_KIND_ARRAY;
        }

        // Hash Reference
        if ( SvTYPE( SvRV( *perl_value ) ) == SVt_PVHV ) {
          return AMQP_FIELD_KIND_TABLE;
        }
        Perl_croak(
          aTHX_ "Unsupported Perl Reference Type: %d",
          SvTYPE( SvRV( *perl_value ) )
        );
      }

      Perl_croak(
        aTHX_ "Unsupported scalar type detected >%s<(%d)",
        SvPV_nolen(*perl_value),
        SvTYPE( *perl_value )
      );
  }

  /* If we're still here... wtf */
  Perl_croak( aTHX_ "The wheels have fallen off. Please call for help." );
}

/* Parallels amqp_read_message */
static amqp_rpc_reply_t read_message(amqp_connection_state_t state, amqp_channel_t channel, SV **props_sv_ptr, SV **body_sv_ptr) {
  HV *props_hv;
  SV *body_sv;
  amqp_rpc_reply_t ret;
  int res;
  amqp_frame_t frame;
  int is_utf8_body = 1; /* The body is UTF-8 by default */

  memset(&ret, 0, sizeof(amqp_rpc_reply_t));

  res = amqp_simple_wait_frame_on_channel(state, channel, &frame);
  if (AMQP_STATUS_OK != res) {
    ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
    ret.library_error = res;
    goto error_out1;
  }

  if (AMQP_FRAME_HEADER != frame.frame_type) {
    if (AMQP_FRAME_METHOD == frame.frame_type &&
        (AMQP_CHANNEL_CLOSE_METHOD == frame.payload.method.id ||
         AMQP_CONNECTION_CLOSE_METHOD == frame.payload.method.id)) {

      ret.reply_type = AMQP_RESPONSE_SERVER_EXCEPTION;
      ret.reply = frame.payload.method;

    } else {
      ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
      ret.library_error = AMQP_STATUS_UNEXPECTED_STATE;

      amqp_put_back_frame(state, &frame);
    }

    goto error_out1;
  }

  {
    amqp_basic_properties_t *p;

    props_hv = newHV();

    p = (amqp_basic_properties_t *) frame.payload.properties.decoded;
    if (p->_flags & AMQP_BASIC_CONTENT_TYPE_FLAG) {
      hv_stores(props_hv, "content_type", newSVpvn(p->content_type.bytes, p->content_type.len));
    }
    if (p->_flags & AMQP_BASIC_CONTENT_ENCODING_FLAG) {
      hv_stores(props_hv, "content_encoding", newSVpvn(p->content_encoding.bytes, p->content_encoding.len));

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
      hv_stores(props_hv, "correlation_id", newSVpvn(p->correlation_id.bytes, p->correlation_id.len));
    }
    if (p->_flags & AMQP_BASIC_REPLY_TO_FLAG) {
      hv_stores(props_hv, "reply_to", newSVpvn(p->reply_to.bytes, p->reply_to.len));
    }
    if (p->_flags & AMQP_BASIC_EXPIRATION_FLAG) {
      hv_stores(props_hv, "expiration", newSVpvn(p->expiration.bytes, p->expiration.len));
    }
    if (p->_flags & AMQP_BASIC_MESSAGE_ID_FLAG) {
      hv_stores(props_hv, "message_id", newSVpvn(p->message_id.bytes, p->message_id.len));
    }
    if (p->_flags & AMQP_BASIC_TYPE_FLAG) {
      hv_stores(props_hv, "type", newSVpvn(p->type.bytes, p->type.len));
    }
    if (p->_flags & AMQP_BASIC_USER_ID_FLAG) {
      hv_stores(props_hv, "user_id", newSVpvn(p->user_id.bytes, p->user_id.len));
    }
    if (p->_flags & AMQP_BASIC_APP_ID_FLAG) {
      hv_stores(props_hv, "app_id", newSVpvn(p->app_id.bytes, p->app_id.len));
    }
    if (p->_flags & AMQP_BASIC_DELIVERY_MODE_FLAG) {
      hv_stores(props_hv, "delivery_mode", newSViv(p->delivery_mode));
    }
    if (p->_flags & AMQP_BASIC_PRIORITY_FLAG) {
      hv_stores(props_hv, "priority", newSViv(p->priority));
    }
    if (p->_flags & AMQP_BASIC_TIMESTAMP_FLAG) {
      hv_stores(props_hv, "timestamp", newSViv(p->timestamp));
    }
    if (p->_flags & AMQP_BASIC_HEADERS_FLAG) {
      int i;
      HV *headers = newHV();
      hv_stores(props_hv, "headers", newRV_noinc(MUTABLE_SV(headers)));

      __DEBUG__( dump_table( p->headers ) );

      for( i=0; i < p->headers.num_entries; ++i ) {
        amqp_table_entry_t *header_entry = &(p->headers.entries[i]);

        __DEBUG__(
          fprintf(stderr,
            "~~~ Length: %ld/%d, Key: %.*s, Kind: %c\n",
            header_entry->key.len,
            (int)header_entry->key.len,
            (int)header_entry->key.len,
            (char*)header_entry->key.bytes,
            header_entry->value.kind
          )
        );

        switch (header_entry->value.kind) {
          case AMQP_FIELD_KIND_BOOLEAN:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSViv(header_entry->value.value.boolean),
                0
            );
            break;

          // Integer types
          case AMQP_FIELD_KIND_I8:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSViv(header_entry->value.value.i8),
                0
            );
            break;

          case AMQP_FIELD_KIND_I16:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSViv(header_entry->value.value.i16),
                0
            );
            break;

          case AMQP_FIELD_KIND_I32:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSViv(header_entry->value.value.i32),
                0
            );
            break;

          case AMQP_FIELD_KIND_I64:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVi64(header_entry->value.value.i64),
                0
            );
            break;

          case AMQP_FIELD_KIND_U8:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVuv(header_entry->value.value.u8),
                0
            );
            break;

          case AMQP_FIELD_KIND_U16:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVuv(header_entry->value.value.u16),
                0
            );
            break;

          case AMQP_FIELD_KIND_U32:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVuv(header_entry->value.value.u32),
                0
            );
            break;

          case AMQP_FIELD_KIND_U64:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVu64(header_entry->value.value.u64),
                0
            );
            break;

          // Floating point precision
          case AMQP_FIELD_KIND_F32:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVnv(header_entry->value.value.f32),
                0
            );
            break;

          case AMQP_FIELD_KIND_F64:
            // TODO: I don't think this is a natively supported type on all Perls.

            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
#ifdef USE_LONG_DOUBLE
                /* amqp uses doubles, if perl is -Duselongdouble it messes up the precision
                 * so we always want take the max precision from a double and discard the rest
                 * because it can't be any more precise than a double */
                newSVnv( ( rint( header_entry->value.value.f64 * DOUBLE_POW ) / DOUBLE_POW ) ),
#else
                /* both of these are doubles so it's ok */
                newSVnv( header_entry->value.value.f64 ),
#endif
                0
            );
            break;

          // Handle kind UTF8 and kind BYTES
          case AMQP_FIELD_KIND_UTF8:
          case AMQP_FIELD_KIND_BYTES:
            hv_store( headers,
                header_entry->key.bytes, header_entry->key.len,
                newSVpvn_utf8(
                  header_entry->value.value.bytes.bytes,
                  header_entry->value.value.bytes.len,
                  AMQP_FIELD_KIND_UTF8 == header_entry->value.kind
                ),
                0
            );
            break;

          // Handle arrays
          case AMQP_FIELD_KIND_ARRAY:
            __DEBUG__(
              fprintf(stderr, "ARRAY KIND FOR KEY:>%.*s< KIND:>%c< AMQP_FIELD_KIND_ARRAY:[%c].\n",
                (int)header_entry->key.len,
                (char*)header_entry->key.bytes,
                header_entry->value.kind,
                AMQP_FIELD_KIND_ARRAY
              )
            );
            hv_store( headers,
              header_entry->key.bytes, header_entry->key.len,
              mq_array_to_arrayref( &header_entry->value.value.array ),
              0
            );
            break;

          // Handle tables (hashes when translated to Perl)
          case AMQP_FIELD_KIND_TABLE:
            hv_store( headers,
              header_entry->key.bytes, header_entry->key.len,
              mq_table_to_hashref( &header_entry->value.value.table ),
              0
            );
            break;

          default:
            ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
            ret.library_error = AMQP_STATUS_UNKNOWN_TYPE;
            goto error_out2;
        }
      }
    }
  }

  {
    char *body;
    size_t body_target = frame.payload.properties.body_size;
    size_t body_remaining = body_target;

    body_sv = newSV(0);
    sv_grow(body_sv, body_target + 1);
    SvCUR_set(body_sv, body_target);
    SvPOK_on(body_sv);
    if (is_utf8_body)
      SvUTF8_on(body_sv);

    body = SvPVX(body_sv);

    while (body_remaining > 0) {
      size_t fragment_len;

      res = amqp_simple_wait_frame_on_channel(state, channel, &frame);
      if (AMQP_STATUS_OK != res) {
        ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
        ret.library_error = res;
        goto error_out3;
      }

      if (AMQP_FRAME_BODY != frame.frame_type) {
        if (AMQP_FRAME_METHOD == frame.frame_type &&
            (AMQP_CHANNEL_CLOSE_METHOD == frame.payload.method.id ||
             AMQP_CONNECTION_CLOSE_METHOD == frame.payload.method.id)) {

          ret.reply_type = AMQP_RESPONSE_SERVER_EXCEPTION;
          ret.reply = frame.payload.method;
        } else {
          ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
          ret.library_error = AMQP_STATUS_BAD_AMQP_DATA;
        }
        goto error_out3;
      }

      fragment_len = frame.payload.body_fragment.len;
      if (fragment_len > body_remaining) {
        ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
        ret.library_error = AMQP_STATUS_BAD_AMQP_DATA;
        goto error_out3;
      }

      memcpy(body, frame.payload.body_fragment.bytes, fragment_len);
      body           += fragment_len;
      body_remaining -= fragment_len;
    }

    *body = '\0';
  }

  *props_sv_ptr = newRV_noinc(MUTABLE_SV(props_hv));
  *body_sv_ptr  = body_sv;
  ret.reply_type = AMQP_RESPONSE_NORMAL;
  return ret;

error_out3:
  SvREFCNT_dec(props_hv);
error_out2:
  SvREFCNT_dec(body_sv);
error_out1:
  *props_sv_ptr = &PL_sv_undef;
  *body_sv_ptr  = &PL_sv_undef;
  return ret;
}

/* Parallels amqp_consume_message */
static amqp_rpc_reply_t consume_message(amqp_connection_state_t state, SV **envelope_sv_ptr, struct timeval *timeout) {
  amqp_rpc_reply_t ret;
  HV *envelope_hv;
  int res;
  amqp_frame_t frame;
  amqp_channel_t channel;
  SV *props;
  SV *body;

  memset(&ret, 0, sizeof(amqp_rpc_reply_t));
  *envelope_sv_ptr = &PL_sv_undef;

  res = amqp_simple_wait_frame_noblock(state, &frame, timeout);
  if (AMQP_STATUS_OK != res) {
    ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
    ret.library_error = res;
    goto error_out1;
  }

  if (AMQP_FRAME_METHOD != frame.frame_type ||
      AMQP_BASIC_DELIVER_METHOD != frame.payload.method.id) {

    if (AMQP_FRAME_METHOD == frame.frame_type &&
        (AMQP_CHANNEL_CLOSE_METHOD == frame.payload.method.id ||
         AMQP_CONNECTION_CLOSE_METHOD == frame.payload.method.id)) {

      ret.reply_type = AMQP_RESPONSE_SERVER_EXCEPTION;
      ret.reply = frame.payload.method;
    } else {
      amqp_put_back_frame(state, &frame);
      ret.reply_type = AMQP_RESPONSE_LIBRARY_EXCEPTION;
      ret.library_error = AMQP_STATUS_UNEXPECTED_STATE;
    }

    goto error_out1;
  }

  channel = frame.channel;

  envelope_hv = newHV();

  {
    amqp_basic_deliver_t *d = (amqp_basic_deliver_t *) frame.payload.method.decoded;
    hv_stores(envelope_hv, "channel",      newSViv(channel));
    hv_stores(envelope_hv, "delivery_tag", newSVu64(d->delivery_tag));
    hv_stores(envelope_hv, "redelivered",  newSViv(d->redelivered));
    hv_stores(envelope_hv, "exchange",     newSVpvn(d->exchange.bytes, d->exchange.len));
    hv_stores(envelope_hv, "consumer_tag", newSVpvn(d->consumer_tag.bytes, d->consumer_tag.len));
    hv_stores(envelope_hv, "routing_key",  newSVpvn(d->routing_key.bytes, d->routing_key.len));
  }

  ret = read_message(state, channel, &props, &body );
  if (AMQP_RESPONSE_NORMAL != ret.reply_type)
    goto error_out2;

  hv_stores(envelope_hv, "props", props);
  hv_stores(envelope_hv, "body", body);

  *envelope_sv_ptr = newRV_noinc(MUTABLE_SV(envelope_hv));
  ret.reply_type = AMQP_RESPONSE_NORMAL;
  return ret;

error_out2:
  SvREFCNT_dec(envelope_hv);
error_out1:
  *envelope_sv_ptr = &PL_sv_undef;
  return ret;
}

void array_to_amqp_array(AV *perl_array, amqp_array_t *mq_array, short force_utf8) {
  int idx = 0;
  SV  **value;

  amqp_field_value_t *new_elements = amqp_pool_alloc(
    &temp_memory_pool,
    ((av_len(perl_array)+1) * sizeof(amqp_field_value_t))
  );
  amqp_field_value_t *element;

  mq_array->entries = new_elements;
  mq_array->num_entries = 0;

  for ( idx = 0; idx <= av_len(perl_array); idx += 1) {
    value = av_fetch( perl_array, idx, 0 );

    // We really should never see NULL here.
    assert(value != NULL);

    // Let's start getting the type...
    element = &mq_array->entries[mq_array->num_entries];
    mq_array->num_entries += 1;
    element->kind = amqp_kind_for_sv(value, force_utf8);

    __DEBUG__( warn("%d KIND >%c<", __LINE__, (unsigned char)element->kind) );

    switch (element->kind) {

      case AMQP_FIELD_KIND_I64:
        element->value.i64 = (int64_t) SvI64(*value);
        break;

      case AMQP_FIELD_KIND_U64:
        element->value.u64 = (uint64_t) SvU64(*value);
        break;

      case AMQP_FIELD_KIND_F64:
        // TODO: I don't think this is a native type on all Perls
        element->value.f64 = (double) SvNV(*value);
        break;

      case AMQP_FIELD_KIND_UTF8:
      case AMQP_FIELD_KIND_BYTES:
        element->value.bytes = amqp_cstring_bytes(SvPV_nolen(*value));
        break;

      case AMQP_FIELD_KIND_ARRAY:
        array_to_amqp_array(MUTABLE_AV(SvRV(*value)), &(element->value.array), force_utf8);
        break;

      case AMQP_FIELD_KIND_TABLE:
        hash_to_amqp_table(MUTABLE_HV(SvRV(*value)), &(element->value.table), force_utf8);
        break;

      default:
        Perl_croak( aTHX_ "Unsupported SvType for array index %d", idx );
    }
  }
}

// Iterate over the array entries and decode them to Perl...
SV* mq_array_to_arrayref(amqp_array_t *mq_array) {
  AV* perl_array = newAV();

  SV* perl_element = &PL_sv_undef;
  amqp_field_value_t* mq_element;

  int current_entry = 0;

  for (; current_entry < mq_array->num_entries; current_entry += 1) {
    mq_element = &mq_array->entries[current_entry];

    __DEBUG__( warn("%d KIND >%c<", __LINE__, mq_element->kind) );

    switch (mq_element->kind) {
      // Boolean
      case AMQP_FIELD_KIND_BOOLEAN:
        perl_element = newSViv(mq_element->value.boolean);
        break;

      // Signed values
      case AMQP_FIELD_KIND_I8:
        perl_element = newSViv(mq_element->value.i8);
        break;
      case AMQP_FIELD_KIND_I16:
        perl_element = newSViv(mq_element->value.i16);
        break;
      case AMQP_FIELD_KIND_I32:
        perl_element = newSViv(mq_element->value.i32);
        break;
      case AMQP_FIELD_KIND_I64:
        perl_element = newSVi64(mq_element->value.i64);
        break;

      // Unsigned values
      case AMQP_FIELD_KIND_U8:
        perl_element = newSViv(mq_element->value.u8);
        break;
      case AMQP_FIELD_KIND_U16:
        perl_element = newSViv(mq_element->value.u16);
        break;
      case AMQP_FIELD_KIND_U32:
        perl_element = newSVuv(mq_element->value.u32);
        break;
      case AMQP_FIELD_KIND_TIMESTAMP: /* Timestamps */
      case AMQP_FIELD_KIND_U64:
        perl_element = newSVu64(mq_element->value.u64);
        break;

      // Floats
      case AMQP_FIELD_KIND_F32:
        perl_element = newSVnv(mq_element->value.f32);
        break;
      case AMQP_FIELD_KIND_F64:
        // TODO: I don't think this is a native type on all Perls
        perl_element = newSVnv(mq_element->value.f64);
        break;

      // Strings and bytes
      case AMQP_FIELD_KIND_BYTES:
        perl_element = newSVpvn(
          mq_element->value.bytes.bytes,
          mq_element->value.bytes.len
        );
        break;

      // UTF-8 strings
      case AMQP_FIELD_KIND_UTF8:
        perl_element = newSVpvn(
          mq_element->value.bytes.bytes,
          mq_element->value.bytes.len
        );
        SvUTF8_on(perl_element); // It's UTF-8!
        break;

      // Arrays
      case AMQP_FIELD_KIND_ARRAY:
        perl_element = mq_array_to_arrayref(&(mq_element->value.array));
        break;

      // Tables
      case AMQP_FIELD_KIND_TABLE:
        perl_element = mq_table_to_hashref(&(mq_element->value.table));
        break;

      // WTF
      default:
        // ACK!
        Perl_croak(
          aTHX_ "Unsupported Perl type >%c< at index %d",
          (unsigned char)mq_element->kind,
          current_entry
        );
    }

    av_push(perl_array, perl_element);
  }

  return newRV_noinc(MUTABLE_SV(perl_array));
}

SV* mq_table_to_hashref( amqp_table_t *mq_table ) {
  // Iterate over the table keys and decode them to Perl...
  int i;
  SV *perl_element;
  HV *perl_hash = newHV();
  amqp_table_entry_t *hash_entry = (amqp_table_entry_t*)NULL;

  for( i=0; i < mq_table->num_entries; i += 1 ) {
    hash_entry = &(mq_table->entries[i]);
    __DEBUG__(
      fprintf(
        stderr,
        "!!! Key: >%.*s< Kind: >%c<\n",
        (int)hash_entry->key.len,
        (char*)hash_entry->key.bytes,
        hash_entry->value.kind
      );
    );

    switch (hash_entry->value.kind) {
      // Boolean
      case AMQP_FIELD_KIND_BOOLEAN:
        perl_element = newSViv(hash_entry->value.value.boolean);
        break;

      // Integers
      case AMQP_FIELD_KIND_I8:
        perl_element = newSViv(hash_entry->value.value.i8);
        break;
      case AMQP_FIELD_KIND_I16:
        perl_element = newSViv(hash_entry->value.value.i16);
        break;
      case AMQP_FIELD_KIND_I32:
        perl_element = newSViv(hash_entry->value.value.i32);
        break;
      case AMQP_FIELD_KIND_I64:
        perl_element = newSVi64(hash_entry->value.value.i64);
        break;
      case AMQP_FIELD_KIND_U8:
        perl_element = newSViv(hash_entry->value.value.u8);
        break;
      case AMQP_FIELD_KIND_U16:
        perl_element = newSViv(hash_entry->value.value.u16);
        break;
      case AMQP_FIELD_KIND_U32:
        perl_element = newSVuv(hash_entry->value.value.u32);
        break;
      case AMQP_FIELD_KIND_TIMESTAMP: /* Timestamps */
      case AMQP_FIELD_KIND_U64:
        perl_element = newSVu64(hash_entry->value.value.u64);
        break;

      // Foats
      case AMQP_FIELD_KIND_F32:
        perl_element = newSVnv(hash_entry->value.value.f32);
        break;
      case AMQP_FIELD_KIND_F64:
        // TODO: I don't think this is a native type on all Perls.
        perl_element = newSVnv(hash_entry->value.value.f64);
        break;

      case AMQP_FIELD_KIND_BYTES:
        perl_element = newSVpvn(
          hash_entry->value.value.bytes.bytes,
          hash_entry->value.value.bytes.len
        );
        break;

      case AMQP_FIELD_KIND_UTF8:
        perl_element = newSVpvn(
          hash_entry->value.value.bytes.bytes,
          hash_entry->value.value.bytes.len
        );
        SvUTF8_on(perl_element); // It's UTF-8!
        break;

      case AMQP_FIELD_KIND_ARRAY:
        perl_element = mq_array_to_arrayref(&(hash_entry->value.value.array));
        break;

      case AMQP_FIELD_KIND_TABLE:
        perl_element = mq_table_to_hashref(&(hash_entry->value.value.table));
        break;

      default:
        // ACK!
        Perl_croak(
          aTHX_ "Unsupported Perl type >%c< at index %d",
          (unsigned char)hash_entry->value.kind,
          i
        );
    }

    // Stash this in our hash.
    hv_store(
      perl_hash,
      hash_entry->key.bytes, hash_entry->key.len,
      perl_element,
      0
    );

  }

  return newRV_noinc(MUTABLE_SV(perl_hash));
}

void hash_to_amqp_table(HV *hash, amqp_table_t *table, short force_utf8) {
  HE   *he;
  char *key;
  SV   *value;
  I32  retlen;
  amqp_table_entry_t *entry;

  amqp_table_entry_t *new_entries = amqp_pool_alloc( &temp_memory_pool, HvKEYS(hash) * sizeof(amqp_table_entry_t) );
  table->entries = new_entries;

  hv_iterinit(hash);
  while (NULL != (he = hv_iternext(hash))) {
    key = hv_iterkey(he, &retlen);
    __DEBUG__( warn("Key: %s\n", key) );
    value = hv_iterval(hash, he);

    if (SvGMAGICAL(value)) {
      mg_get(value);
    }

    entry = &table->entries[table->num_entries];
    entry->key = amqp_cstring_bytes( key );

    // Reserved headers, per spec must force UTF-8 for strings.
    // Other headers aren't necessarily required to do so.
    if (
      // "x-*" exchanges
      (
        strlen(key) > 2
        &&
        key[0] == 'x'
        &&
        key[1] == '-'
      )
    ) {
      entry->value.kind = amqp_kind_for_sv( &value, 1 );
    }
    else {
      entry->value.kind = amqp_kind_for_sv( &value, force_utf8 );
    }


    __DEBUG__(
      warn("hash_to_amqp_table()");
      warn("%s", SvPV_nolen(value) );
      fprintf(
        stderr,
        "Key: >%.*s< Kind: >%c<\n",
        (int)entry->key.len,
        (char*)entry->key.bytes,
        entry->value.kind
      );
    );

    switch ( entry->value.kind ) {
      case AMQP_FIELD_KIND_I64:
        entry->value.value.i64 = (int64_t) SvI64( value );
        break;

      case AMQP_FIELD_KIND_U64:
        entry->value.value.u64 = (uint64_t) SvU64( value );
        break;

      case AMQP_FIELD_KIND_F64:
        // TODO: I don't think this is a native type on all Perls.
        entry->value.value.f64 = (double) SvNV( value );
        break;

      case AMQP_FIELD_KIND_BYTES:
      case AMQP_FIELD_KIND_UTF8:
        entry->value.value.bytes = amqp_cstring_bytes( SvPV_nolen( value )
        );
        break;

      case AMQP_FIELD_KIND_ARRAY:
        array_to_amqp_array(
          MUTABLE_AV(SvRV(value)),
          &(entry->value.value.array),
          force_utf8
        );
        break;

      case AMQP_FIELD_KIND_TABLE:
        hash_to_amqp_table(
          MUTABLE_HV(SvRV(value)),
          &(entry->value.value.table),
          force_utf8
        );
        break;

      default:
        Perl_croak( aTHX_ "amqp_kind_for_sv() returned a type I don't understand." );
    }

    // Successfully (we think) added an entry to the table.
    table->num_entries++;
  }

  return;
}

static amqp_rpc_reply_t basic_get(amqp_connection_state_t state, amqp_channel_t channel, amqp_bytes_t queue, SV **envelope_sv_ptr, amqp_boolean_t no_ack) {
  amqp_rpc_reply_t ret;
  HV *envelope_hv = NULL;
  SV *props;
  SV *body;

  ret = amqp_basic_get(state, channel, queue, no_ack);
  if (AMQP_RESPONSE_NORMAL != ret.reply_type)
    goto error_out1;

  if (AMQP_BASIC_GET_OK_METHOD != ret.reply.id)
    goto success_out;

  envelope_hv = newHV();

  {
    amqp_basic_get_ok_t *ok = (amqp_basic_get_ok_t *) ret.reply.decoded;
    hv_stores(envelope_hv, "delivery_tag",  newSVu64(ok->delivery_tag));
    hv_stores(envelope_hv, "redelivered",   newSViv(ok->redelivered));
    hv_stores(envelope_hv, "exchange",      newSVpvn(ok->exchange.bytes, ok->exchange.len));
    hv_stores(envelope_hv, "routing_key",   newSVpvn(ok->routing_key.bytes, ok->routing_key.len));
    hv_stores(envelope_hv, "message_count", newSViv(ok->message_count));
  }

  ret = read_message(state, channel, &props, &body );
  if (AMQP_RESPONSE_NORMAL != ret.reply_type)
    goto error_out2;

  hv_stores(envelope_hv, "props", props);
  hv_stores(envelope_hv, "body", body);
  
success_out:
  *envelope_sv_ptr = envelope_hv ? newRV_noinc(MUTABLE_SV(envelope_hv)) : &PL_sv_undef;
  ret.reply_type = AMQP_RESPONSE_NORMAL;
  return ret;

error_out2:
  SvREFCNT_dec(envelope_hv);
error_out1:
  *envelope_sv_ptr = &PL_sv_undef;
  return ret;
}



MODULE = Net::AMQP::RabbitMQ PACKAGE = Net::AMQP::RabbitMQ PREFIX = net_amqp_rabbitmq_

REQUIRE:        1.9505
PROTOTYPES:     DISABLE

BOOT:
  PERL_MATH_INT64_LOAD_OR_CROAK;

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

    int ssl = 0;
    char *ssl_cacert = NULL;
    char *ssl_cert = NULL;
    char *ssl_key = NULL;
    int ssl_verify_host = 1;
    int ssl_init = 1;
    char *sasl_method = "plain";
    amqp_sasl_method_enum sasl_type = AMQP_SASL_METHOD_PLAIN;
  CODE:
    str_from_hv(options, user);
    str_from_hv(options, password);
    str_from_hv(options, vhost);
    int_from_hv(options, channel_max);
    int_from_hv(options, frame_max);
    int_from_hv(options, heartbeat);
    int_from_hv(options, port);
    double_from_hv(options, timeout);

    int_from_hv(options, ssl);
    str_from_hv(options, ssl_cacert);
    str_from_hv(options, ssl_cert);
    str_from_hv(options, ssl_key);
    int_from_hv(options, ssl_verify_host);
    int_from_hv(options, ssl_init);
    str_from_hv(options, sasl_method);

    if(timeout >= 0) {
     to.tv_sec = floor(timeout);
     to.tv_usec = 1000000.0 * (timeout - floor(timeout));
    }

    if ( ssl ) {
#ifndef NAR_HAVE_OPENSSL
        Perl_croak(aTHX_ "no ssl support, please install openssl and reinstall");
#endif
        amqp_set_initialize_ssl_library( (amqp_boolean_t)ssl_init );
        sock = amqp_ssl_socket_new(conn);
        if ( !sock ) {
          Perl_croak(aTHX_ "error creating SSL socket");
        }

        amqp_ssl_socket_set_verify_hostname( sock, (amqp_boolean_t)ssl_verify_host );

        if ( ( ssl_cacert != NULL ) && strlen(ssl_cacert) ) {
            if ( amqp_ssl_socket_set_cacert(sock, ssl_cacert) ) {
                Perl_croak(aTHX_ "error setting CA certificate");
            }
        }
        else {
            // TODO
            // in librabbitmq > 0.7.1, amqp_ssl_socket_set_verify_peer makes this optional
            Perl_croak(aTHX_ "required arg ssl_cacert not provided");
        }

        if ( ( ssl_key != NULL ) && strlen(ssl_key) && ( ssl_cert != NULL ) && strlen(ssl_cert) ) {
            if ( amqp_ssl_socket_set_key( sock, ssl_cert, ssl_key ) ) {
                Perl_croak(aTHX_ "error setting client cert");
            }
        }
    }
    else {
        sock = amqp_tcp_socket_new(conn);
        if (!sock) {
          Perl_croak(aTHX_ "error creating TCP socket");
        }
    }

    //if there's data in the buffer, clear it
    while ( amqp_data_in_buffer(conn) ) {
        amqp_frame_t frame;
        amqp_simple_wait_frame( conn, &frame );
    }

    // should probably be amqp_raw_equal, but this is a minimal hack
    if (strcasecmp(sasl_method, "external") == 0) {
       sasl_type = AMQP_SASL_METHOD_EXTERNAL;
    }

    die_on_error(aTHX_ amqp_socket_open_noblock(sock, hostname, port, (timeout<0)?NULL:&to), conn, "opening socket");
    die_on_amqp_error(aTHX_ amqp_login(conn, vhost, channel_max, frame_max, heartbeat, sasl_type, user, password), conn, "Logging in");

    maybe_release_buffers(conn);

    RETVAL = 1;
  OUTPUT:
    RETVAL

void
net_amqp_rabbitmq_channel_open(conn, channel)
  Net::AMQP::RabbitMQ conn
  int channel
  CODE:
    assert_amqp_connected(conn);

    amqp_channel_open(conn, channel);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Opening channel");

void
net_amqp_rabbitmq_channel_close(conn, channel)
  Net::AMQP::RabbitMQ conn
  int channel
  CODE:
    /* If we don't have a socket, just return. */
    if ( ! has_valid_connection( conn ) ) {
      return;
    }
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
    int auto_delete = 0;
    int internal = 0;
    amqp_table_t arguments = amqp_empty_table;
  CODE:
    assert_amqp_connected(conn);

    if(options) {
      str_from_hv(options, exchange_type);
      int_from_hv(options, passive);
      int_from_hv(options, durable);
      int_from_hv(options, auto_delete);
      int_from_hv(options, internal);
    }
    if(args)
    {
      hash_to_amqp_table(args, &arguments, 1);
    }
    amqp_exchange_declare(
      conn,
      channel,
      amqp_cstring_bytes(exchange),
      amqp_cstring_bytes(exchange_type),
      passive,
      (amqp_boolean_t)durable,
      (amqp_boolean_t)auto_delete,
      (amqp_boolean_t)internal,
      arguments
    );
    maybe_release_buffers(conn);
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
    assert_amqp_connected(conn);

    if(options) {
      int_from_hv(options, if_unused);
    }
    amqp_exchange_delete(conn, channel, amqp_cstring_bytes(exchange), if_unused);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Deleting exchange");

void net_amqp_rabbitmq_exchange_bind(conn, channel, destination, source, routing_key, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *destination
  char *source
  char *routing_key
  HV *args
  PREINIT:
    amqp_exchange_bind_ok_t *reply = (amqp_exchange_bind_ok_t*)NULL;
    amqp_table_t arguments = amqp_empty_table;
  CODE:
    // We must be connected
    assert_amqp_connected(conn);

    // Parameter validation
    if( ( source == NULL || 0 == strlen(source) )
      ||
      ( destination == NULL || 0 == strlen(destination) )
    )
    {
      Perl_croak(aTHX_ "source and destination must both be specified");
    }

    // Pull in arguments if we have any
    if(args)
    {
      hash_to_amqp_table(args, &arguments, 1);
    }

    reply = amqp_exchange_bind(
      conn,
      channel,
      amqp_cstring_bytes(destination),
      amqp_cstring_bytes(source),
      amqp_cstring_bytes(routing_key),
      arguments
    );
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Binding Exchange");

void net_amqp_rabbitmq_exchange_unbind(conn, channel, destination, source, routing_key, args = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *destination
  char *source
  char *routing_key
  HV *args
  PREINIT:
    amqp_exchange_unbind_ok_t *reply = (amqp_exchange_unbind_ok_t*)NULL;
    amqp_table_t arguments = amqp_empty_table;
  CODE:
    // We must be connected
    assert_amqp_connected(conn);

    // Parameter validation
    if( ( source == NULL || 0 == strlen(source) )
      ||
      ( destination == NULL || 0 == strlen(destination) )
    )
    {
      Perl_croak(aTHX_ "source and destination must both be specified");
    }

    // Pull in arguments if we have any
    if(args)
    {
      hash_to_amqp_table(args, &arguments, 1);
    }

    reply = amqp_exchange_unbind(
      conn,
      channel,
      amqp_cstring_bytes(destination),
      amqp_cstring_bytes(source),
      amqp_cstring_bytes(routing_key),
      arguments
    );
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Unbinding Exchange");

void net_amqp_rabbitmq_queue_delete(conn, channel, queuename, options = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  HV *options
  PREINIT:
    int if_unused = 1;
    int if_empty = 1;
    amqp_queue_delete_ok_t *reply = (amqp_queue_delete_ok_t*)NULL;
  CODE:
    assert_amqp_connected(conn);

    if(options) {
      int_from_hv(options, if_unused);
      int_from_hv(options, if_empty);
    }
    reply = amqp_queue_delete(
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
    amqp_queue_declare_ok_t *r = (amqp_queue_declare_ok_t*)NULL;
  PPCODE:
    assert_amqp_connected(conn);

    if(queuename && strcmp(queuename, "")) queuename_b = amqp_cstring_bytes(queuename);
    if(options) {
      int_from_hv(options, passive);
      int_from_hv(options, durable);
      int_from_hv(options, exclusive);
      int_from_hv(options, auto_delete);
    }
    if(args)
    {
      hash_to_amqp_table(args, &arguments, 1);
    }
    r = amqp_queue_declare(conn, channel, queuename_b, passive,
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
    assert_amqp_connected(conn);

    if(queuename == NULL
      ||
      exchange == NULL
      ||
      0 == strlen(queuename)
      ||
      0 == strlen(exchange)
    )
    {
      Perl_croak(aTHX_ "queuename and exchange must both be specified");
    }

    if(args)
      hash_to_amqp_table(args, &arguments, 0);
    amqp_queue_bind(conn, channel, amqp_cstring_bytes(queuename),
                    amqp_cstring_bytes(exchange),
                    amqp_cstring_bytes(bindingkey),
                    arguments);
    maybe_release_buffers(conn);
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
    assert_amqp_connected(conn);

    if(queuename == NULL || exchange == NULL)
    {
      Perl_croak(aTHX_ "queuename and exchange must both be specified");
    }

    if(args)
    {
      hash_to_amqp_table(args, &arguments, 0);
    }
    amqp_queue_unbind(conn, channel, amqp_cstring_bytes(queuename),
                      amqp_cstring_bytes(exchange),
                    amqp_cstring_bytes(bindingkey),
                    arguments);
    maybe_release_buffers(conn);
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
    assert_amqp_connected(conn);

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

int
net_amqp_rabbitmq_cancel(conn, channel, consumer_tag)
  Net::AMQP::RabbitMQ conn
  int channel
  char *consumer_tag
  PREINIT:
    amqp_basic_cancel_ok_t *r;
  CODE:
    assert_amqp_connected(conn);

    r = amqp_basic_cancel(conn, channel, amqp_cstring_bytes(consumer_tag));
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "cancel");

    if ( r == NULL ) {
        RETVAL = 0;
    }
    else {
        if(strlen(consumer_tag) == r->consumer_tag.len && 0 == strcmp(consumer_tag, (char *)r->consumer_tag.bytes)) {
          RETVAL = 1;
        } else {
          RETVAL = 0;
        }
    }
  OUTPUT:
    RETVAL

SV *
net_amqp_rabbitmq_recv(conn, timeout = 0)
  Net::AMQP::RabbitMQ conn
  int timeout
  PREINIT:
    SV *envelope;
    amqp_rpc_reply_t ret;
    struct timeval timeout_tv;
  CODE:
    assert_amqp_connected(conn);

    if (timeout > 0) {
      timeout_tv.tv_sec = timeout / 1000;
      timeout_tv.tv_usec = (timeout % 1000) * 1000;
    }

    // Set the waiting time to 0
    if (timeout == -1) {
      timeout_tv.tv_sec = 0;
      timeout_tv.tv_usec = 0;
    }

    maybe_release_buffers(conn);
    ret = consume_message(conn, &RETVAL, timeout ? &timeout_tv : NULL);
    if (AMQP_RESPONSE_LIBRARY_EXCEPTION != ret.reply_type || AMQP_STATUS_TIMEOUT != ret.library_error)
      die_on_amqp_error(aTHX_ ret, conn, "recv");

  OUTPUT:
    RETVAL

void
net_amqp_rabbitmq_ack(conn, channel, delivery_tag, multiple = 0)
  Net::AMQP::RabbitMQ conn
  int channel
  uint64_t delivery_tag
  int multiple
  CODE:
    assert_amqp_connected(conn);

    die_on_error(aTHX_ amqp_basic_ack(conn, channel, delivery_tag, multiple), conn,
                 "ack");

void
net_amqp_rabbitmq_nack(conn, channel, delivery_tag, multiple = 0, requeue = 0)
  Net::AMQP::RabbitMQ conn
  int channel
  uint64_t delivery_tag
  int multiple
  int requeue
  CODE:
    assert_amqp_connected(conn);

    die_on_error(
      aTHX_ amqp_basic_nack(
        conn,
        channel,
        delivery_tag,
        (amqp_boolean_t)multiple,
        (amqp_boolean_t)requeue
      ),
      conn,
      "nack"
    );

void
net_amqp_rabbitmq_reject(conn, channel, delivery_tag, requeue = 0)
  Net::AMQP::RabbitMQ conn
  int channel
  uint64_t delivery_tag
  int requeue
  CODE:
    assert_amqp_connected(conn);

    die_on_error(
      aTHX_ amqp_basic_reject(
        conn,
        channel,
        delivery_tag,
        requeue
      ),
      conn,
      "reject"
    );


void
net_amqp_rabbitmq_purge(conn, channel, queuename)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  CODE:
    assert_amqp_connected(conn);

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
    int force_utf8_in_header_strings = 0;
  CODE:
    assert_amqp_connected(conn);

    routing_key_b = amqp_cstring_bytes(routing_key);
    body_b.bytes = SvPV(body, len);
    body_b.len = len;
    if(options) {
      if(NULL != (v = hv_fetchs(options, "mandatory", 0))) {
        mandatory = SvIV(*v) ? 1 : 0;
      }
      if(NULL != (v = hv_fetchs(options, "immediate", 0))) {
        immediate = SvIV(*v) ? 1 : 0;
      }
      if(NULL != (v = hv_fetchs(options, "exchange", 0))) {
        exchange_b = amqp_cstring_bytes(SvPV_nolen(*v));
      }

      // This is an internal option, only for determining if we want to force utf8
      int_from_hv(options, force_utf8_in_header_strings);
    }
    properties.headers = amqp_empty_table;
    properties._flags = 0;
    if (props) {
      if (NULL != (v = hv_fetchs(props, "content_type", 0))) {
        properties.content_type     = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_CONTENT_TYPE_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "content_encoding", 0))) {
        properties.content_encoding = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_CONTENT_ENCODING_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "correlation_id", 0))) {
        properties.correlation_id   =  amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_CORRELATION_ID_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "reply_to", 0))) {
        properties.reply_to         = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_REPLY_TO_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "expiration", 0))) {
        properties.expiration       = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_EXPIRATION_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "message_id", 0))) {
        properties.message_id       = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_MESSAGE_ID_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "type", 0))) {
        properties.type             = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_TYPE_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "user_id", 0))) {
        properties.user_id          = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_USER_ID_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "app_id", 0))) {
        properties.app_id           = amqp_cstring_bytes(SvPV_nolen(*v));
        properties._flags |= AMQP_BASIC_APP_ID_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "delivery_mode", 0))) {
        properties.delivery_mode    = (uint8_t) SvIV(*v);
        properties._flags |= AMQP_BASIC_DELIVERY_MODE_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "priority", 0))) {
        properties.priority         = (uint8_t) SvIV(*v);
        properties._flags |= AMQP_BASIC_PRIORITY_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "timestamp", 0))) {
        properties.timestamp        = (uint64_t) SvI64(*v);
        properties._flags |= AMQP_BASIC_TIMESTAMP_FLAG;
      }
      if (NULL != (v = hv_fetchs(props, "headers", 0)) && SvOK(*v)) {
        hash_to_amqp_table(MUTABLE_HV(SvRV(*v)), &properties.headers, force_utf8_in_header_strings);
        properties._flags |= AMQP_BASIC_HEADERS_FLAG;
      }
    }
    __DEBUG__( warn("PUBLISHING HEADERS..."); dump_table( properties.headers ) );
    rv = amqp_basic_publish(conn, channel, exchange_b, routing_key_b, mandatory, immediate, &properties, body_b);
    maybe_release_buffers(conn);

    /* If the connection failed, blast the file descriptor! */
    if ( rv == AMQP_STATUS_CONNECTION_CLOSED || rv == AMQP_STATUS_SOCKET_ERROR ) {
        amqp_socket_close( amqp_get_socket( conn ) );
        Perl_croak(aTHX_ "Publish failed because AMQP socket connection was closed.");
    }

    /* Otherwise, just croak */
    if ( rv != AMQP_STATUS_OK ) {
        Perl_croak( aTHX_ "Publish failed, %s\n", amqp_error_string2(rv));
    }

SV *
net_amqp_rabbitmq_get(conn, channel, queuename, options = NULL)
  Net::AMQP::RabbitMQ conn
  int channel
  char *queuename
  HV *options
  PREINIT:
    int no_ack = 1;
  CODE:
    assert_amqp_connected(conn);

    if (options)
      int_from_hv(options, no_ack);

    maybe_release_buffers(conn);
    die_on_amqp_error(aTHX_ basic_get(conn, channel, queuename ? amqp_cstring_bytes(queuename) : amqp_empty_bytes, &RETVAL, no_ack), conn, "basic_get");

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
net_amqp_rabbitmq_get_sockfd(conn)
  Net::AMQP::RabbitMQ conn
  CODE:
/**
 * this is the warning from librabbitmq-c. you have been warned.
 *
 * \warning Use the socket returned from this function carefully, incorrect use
 * of the socket outside of the library will lead to undefined behavior.
 * Additionally rabbitmq-c may use the socket differently version-to-version,
 * what may work in one version, may break in the next version. Be sure to
 * throughly test any applications that use the socket returned by this
 * function especially when using a newer version of rabbitmq-c
 *
 */
    if ( has_valid_connection( conn ) ) {
      RETVAL = newSViv( amqp_get_sockfd(conn) );
    }
    else {
      // We don't have a connection, we're still here.
      RETVAL = &PL_sv_undef;
    }
  OUTPUT:
    RETVAL

SV*
net_amqp_rabbitmq_is_connected(conn)
  Net::AMQP::RabbitMQ conn
  CODE:
    if ( has_valid_connection( conn ) ) {
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
    if ( amqp_get_socket(conn) != NULL ) {
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
    if ( amqp_get_socket(conn) != NULL ) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
    }
    empty_amqp_pool( &temp_memory_pool );
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
  CODE:
    amqp_tx_commit(conn, channel);
    maybe_release_buffers(conn);
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
      if(NULL != (v = hv_fetchs(args, "prefetch_size", 0))) prefetch_size = SvIV(*v);
      if(NULL != (v = hv_fetchs(args, "prefetch_count", 0))) prefetch_count = SvIV(*v);
      if(NULL != (v = hv_fetchs(args, "global", 0))) global = SvIV(*v) ? 1 : 0;
    }
    amqp_basic_qos(conn, channel,
                   prefetch_size, prefetch_count, global);
    die_on_amqp_error(aTHX_ amqp_get_rpc_reply(conn), conn, "Basic QoS");

SV* net_amqp_rabbitmq_get_server_properties(conn)
  Net::AMQP::RabbitMQ conn
  PREINIT:
    amqp_table_t* server_properties;
  CODE:
    assert_amqp_connected(conn);
    server_properties = amqp_get_server_properties(conn);
    if ( server_properties )
    {
      RETVAL = mq_table_to_hashref(server_properties);
    }
    else
    {
      RETVAL = &PL_sv_undef;
    }
  OUTPUT:
    RETVAL

SV* net_amqp_rabbitmq_get_client_properties(conn)
  Net::AMQP::RabbitMQ conn
  PREINIT:
    amqp_table_t* client_properties;
  CODE:
    assert_amqp_connected(conn);
    client_properties = amqp_get_client_properties(conn);
    if ( client_properties )
    {
      RETVAL = mq_table_to_hashref(client_properties);
    }
    else
    {
      RETVAL = &PL_sv_undef;
    }
  OUTPUT:
    RETVAL

SV* net_amqp_rabbitmq_has_ssl()
  CODE:
#ifdef NAR_HAVE_OPENSSL
    RETVAL = &PL_sv_yes;
#else
    RETVAL = &PL_sv_no;
#endif
  OUTPUT:
    RETVAL
