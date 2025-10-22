#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <ctype.h>

#include <rabbitmq-c/amqp.h>
#include <errno.h>
#include <stdarg.h>
#include <errno.h>

#include <inttypes.h>

static void dump_row(long count, int numinrow, int *chs) {
  int i;

  printf("%08lX:", count - numinrow);

  if (numinrow > 0) {
    for (i = 0; i < numinrow; i++) {
      if (i == 8)
	printf(" :");
      printf(" %02X", chs[i]);
    }
    for (i = numinrow; i < 16; i++) {
      if (i == 8)
	printf(" :");
      printf("   ");
    }
    printf("  ");
    for (i = 0; i < numinrow; i++) {
      if (isprint(chs[i]))
	printf("%c", chs[i]);
      else
	printf(".");
    }
  }
  printf("\n");
}

static int rows_eq(int *a, int *b) {
  int i;

  for (i=0; i<16; i++)
    if (a[i] != b[i])
      return 0;

  return 1;
}

void amqp_dump(void const *buffer, size_t len) {
  unsigned char *buf = (unsigned char *) buffer;
  long count = 0;
  int numinrow = 0;
  int chs[16];
  int oldchs[16];
  int showed_dots = 0;
  int i;

  for (i = 0; i < len; i++) {
    int ch = buf[i];

    if (numinrow == 16) {
      int i;

      if (rows_eq(oldchs, chs)) {
	if (!showed_dots) {
	  showed_dots = 1;
	  printf("          .. .. .. .. .. .. .. .. : .. .. .. .. .. .. .. ..\n");
	}
      } else {
	showed_dots = 0;
	dump_row(count, numinrow, chs);
      }

      for (i=0; i<16; i++)
	oldchs[i] = chs[i];

      numinrow = 0;
    }

    count++;
    chs[numinrow++] = ch;
  }

  dump_row(count, numinrow, chs);

  if (numinrow != 0)
    printf("%08lX:\n", count);
}

static void dump_indent(int indent, FILE *out) {
  int i;

  for (i = 0; i < indent; i++) {
    fputc(' ', out);
  }
}

void say( char *buffer ) {
    fprintf(stderr, "%s", buffer );
}

static void dump_value(int indent, amqp_field_value_t v, FILE *out) {
  int i;

  dump_indent(indent, out);
  fputc(v.kind, out);

  switch (v.kind) {
  case AMQP_FIELD_KIND_BOOLEAN:
    fputs(v.value.boolean ? " true\n" : " false\n", out);
    break;

  case AMQP_FIELD_KIND_I8:
    fprintf(out, " %"PRId8"\n", v.value.i8);
    break;

  case AMQP_FIELD_KIND_U8:
    fprintf(out, " %"PRIu8"\n", v.value.u8);
    break;

  case AMQP_FIELD_KIND_I16:
    fprintf(out, " %"PRId16"\n", v.value.i16);
    break;

  case AMQP_FIELD_KIND_U16:
    fprintf(out, " %"PRIu16"\n", v.value.u16);
    break;

  case AMQP_FIELD_KIND_I32:
    fprintf(out, " %"PRId32"\n", v.value.i32);
    break;

  case AMQP_FIELD_KIND_U32:
    fprintf(out, " %"PRIu32"\n", v.value.u32);
    break;

  case AMQP_FIELD_KIND_I64:
    fprintf(out, " %"PRId64"\n", v.value.i64);
    break;

  case AMQP_FIELD_KIND_F32:
    fprintf(out, " %g\n", (double) v.value.f32);
    break;

  case AMQP_FIELD_KIND_F64:
    fprintf(out, " %g\n", v.value.f64);
    break;

  case AMQP_FIELD_KIND_DECIMAL:
    fprintf(out, " %d:::%u\n", v.value.decimal.decimals,
            v.value.decimal.value);
    break;

  case AMQP_FIELD_KIND_UTF8:
    fprintf(out, " %.*s\n", (int)v.value.bytes.len,
            (char *)v.value.bytes.bytes);
    break;

  case AMQP_FIELD_KIND_BYTES:
    fputc(' ', out);
    for (i = 0; i < (int)v.value.bytes.len; i++) {
      fprintf(out, "%02x", ((char *) v.value.bytes.bytes)[i]);
    }

    fputc('\n', out);
    break;

  case AMQP_FIELD_KIND_ARRAY:
    fputc('\n', out);
    for (i = 0; i < v.value.array.num_entries; i++) {
      dump_value(indent + 2, v.value.array.entries[i], out);
    }

    break;

  case AMQP_FIELD_KIND_TIMESTAMP:
    fprintf(out, " %"PRIu64"\n", v.value.u64);
    break;

  case AMQP_FIELD_KIND_TABLE:
    fputc('\n', out);
    for (i = 0; i < v.value.table.num_entries; i++) {
      dump_indent(indent + 2, out);
      fprintf(out, "%.*s ->\n",
              (int)v.value.table.entries[i].key.len,
              (char *)v.value.table.entries[i].key.bytes);
      dump_value(indent + 4, v.value.table.entries[i].value, out);
    }

    break;

  case AMQP_FIELD_KIND_VOID:
    fputc('\n', out);
    break;

  default:
    fprintf(out, "???\n");
    break;
  }
}

void dump_table(amqp_table_t table) {
  fprintf(stderr, "Dump start\n");

  amqp_field_value_t val;
  val.kind = AMQP_FIELD_KIND_TABLE;
  val.value.table = table;
  dump_value(0, val, stderr);
}
