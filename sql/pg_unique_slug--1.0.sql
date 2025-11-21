-- pg_unique_slug extension version 1.0

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_unique_slug" to load this file. \quit

CREATE FUNCTION gen_unique_slug(slug_length int DEFAULT 16)
RETURNS text
AS 'MODULE_PATHNAME'
LANGUAGE C
VOLATILE;

COMMENT ON FUNCTION gen_unique_slug(int) IS
'Generate a unique slug based on timestamp with randomized character mapping.
Parameters:
  slug_length: 10 (seconds), 13 (milliseconds), 16 (microseconds), 19 (nanoseconds)
  Default: 16 (microseconds)
Returns: Unique slug with hyphen separator (e.g., "qWeRtYuI-oPasDfGh")
Guarantees uniqueness when there is at most one insert per time unit.';
