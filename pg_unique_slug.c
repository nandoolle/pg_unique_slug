/*
 * pg_unique_slug.c - PostgreSQL extension for generating unique random slugs
 *
 * Generates unique slugs based on timestamp with randomized character mapping.
 * Each digit of the timestamp maps to a bucket of letters, ensuring uniqueness
 * when there's at most one insert per time unit.
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "common/pg_prng.h"
#include <time.h>

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(gen_unique_slug);

/*
 * 52 letters distributed across 10 buckets (one per digit 0-9)
 * Following QWERTY layout with alternating capitalization pattern
 * Buckets 0,2,4,6,8: min-MAI-min-MAI pattern
 * Buckets 1,3,5,7,9: MAI-min-MAI-min pattern
 */
static const char *digit_buckets[10] = {
    "qWeRtY",    /* 0: 6 letters */
    "QwErTy",    /* 1: 6 letters */
    "uIoPa",     /* 2: 5 letters */
    "UiOpA",     /* 3: 5 letters */
    "sDfGh",     /* 4: 5 letters */
    "SdFgH",     /* 5: 5 letters */
    "jKlZx",     /* 6: 5 letters */
    "JkLzX",     /* 7: 5 letters */
    "cVbNm",     /* 8: 5 letters */
    "CvBnM"      /* 9: 5 letters */
};

static const int bucket_sizes[10] = {6, 6, 5, 5, 5, 5, 5, 5, 5, 5};

/*
 * Get current timestamp with specified precision
 */
static uint64
get_timestamp_value(int precision)
{
    struct timespec ts;

    clock_gettime(CLOCK_REALTIME, &ts);

    switch (precision) {
        case 10:  /* seconds */
            return (uint64) ts.tv_sec;
        case 13:  /* milliseconds */
            return (uint64) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
        case 16:  /* microseconds */
            return (uint64) ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
        case 19:  /* nanoseconds */
            return (uint64) ts.tv_sec * 1000000000 + ts.tv_nsec;
        default:
            return (uint64) ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
    }
}

/*
 * Convert timestamp to slug using bucket mapping
 */
static void
timestamp_to_slug(uint64 ts, int len, char *slug)
{
    char digits[20];
    int  half;
    int  slug_pos = 0;

    /* Convert timestamp to string of digits with leading zeros */
    snprintf(digits, sizeof(digits), "%0*llu", len, (unsigned long long) ts);

    /* Calculate where to put the hyphen */
    half = len / 2;

    /* Map each digit to a random letter from its bucket */
    for (int i = 0; i < len; i++) {
        int digit = digits[i] - '0';
        int bucket_size = bucket_sizes[digit];
        unsigned char rnd;

        /* Insert hyphen at midpoint */
        if (i == half) {
            slug[slug_pos++] = '-';
        }

        /* Get random index into bucket */
        if (!pg_strong_random(&rnd, 1)) {
            ereport(ERROR, (errmsg("pg_strong_random failed")));
        }

        slug[slug_pos++] = digit_buckets[digit][rnd % bucket_size];
    }

    slug[slug_pos] = '\0';
}

Datum
gen_unique_slug(PG_FUNCTION_ARGS)
{
    int32   len;
    uint64  ts;
    char    slug[22];  /* max: 19 chars + 1 hyphen + 1 null + 1 extra */

    /* Get length parameter, default to 16 if not provided */
    if (PG_ARGISNULL(0)) {
        len = 16;
    } else {
        len = PG_GETARG_INT32(0);
    }

    /* Validate length - only 10, 13, 16, 19 allowed */
    if (len != 10 && len != 13 && len != 16 && len != 19) {
        ereport(ERROR,
                (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                 errmsg("slug_length must be 10, 13, 16, or 19"),
                 errhint("10=seconds, 13=milliseconds, 16=microseconds, 19=nanoseconds")));
    }

    /* Get timestamp with appropriate precision */
    ts = get_timestamp_value(len);

    /* Convert to slug */
    timestamp_to_slug(ts, len, slug);

    PG_RETURN_TEXT_P(cstring_to_text(slug));
}
