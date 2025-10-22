
#ifndef RABBITMQ_C_EXPORT_H
#define RABBITMQ_C_EXPORT_H

#ifdef AMQP_STATIC
#  define AMQP_EXPORT
#  define AMQP_NO_EXPORT
#else
#  ifndef AMQP_EXPORT
#    ifdef rabbitmq_EXPORTS
        /* We are building this library */
#      define AMQP_EXPORT __attribute__((visibility("default")))
#    else
        /* We are using this library */
#      define AMQP_EXPORT __attribute__((visibility("default")))
#    endif
#  endif

#  ifndef AMQP_NO_EXPORT
#    define AMQP_NO_EXPORT __attribute__((visibility("hidden")))
#  endif
#endif

#ifndef AMQP_DEPRECATED
#  define AMQP_DEPRECATED __attribute__ ((__deprecated__))
#endif

#ifndef AMQP_DEPRECATED_EXPORT
#  define AMQP_DEPRECATED_EXPORT AMQP_EXPORT AMQP_DEPRECATED
#endif

#ifndef AMQP_DEPRECATED_NO_EXPORT
#  define AMQP_DEPRECATED_NO_EXPORT AMQP_NO_EXPORT AMQP_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef AMQP_NO_DEPRECATED
#    define AMQP_NO_DEPRECATED
#  endif
#endif

#endif /* RABBITMQ_C_EXPORT_H */
