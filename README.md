# pg_unique_slug

PostgreSQL extension for generating unique random slugs based on timestamp.

## Features

- **Guaranteed Uniqueness**: Based on timestamp - unique when max 1 insert per time unit
- **Cryptographically Random**: Uses `pg_strong_random()` for character selection
- **Configurable Precision**: seconds, milliseconds, microseconds, or nanoseconds
- **URL-Friendly**: Only letters A-Z, a-z with hyphen separator
- **QWERTY Layout**: Characters distributed following keyboard layout

## Installation

### From Source

```bash
make
make install
```

### Enable Extension

```sql
CREATE EXTENSION pg_unique_slug;
```

### Using Docker (Development)

```bash
./dev.sh start
./dev.sh rebuild
./dev.sh psql
```

## Usage

### Function Signature

```sql
gen_unique_slug(slug_length int DEFAULT 16) RETURNS text
```

### Interface

```sql
gen_unique_slug()      -- default: 16 (microseconds)
gen_unique_slug(10)    -- seconds
gen_unique_slug(13)    -- milliseconds
gen_unique_slug(16)    -- microseconds
gen_unique_slug(19)    -- nanoseconds
```

### Timestamp Precision

Each precision level corresponds to Unix timestamp digits:

| Precision     | Digits | Timestamp Example   | Max Inserts (collision-free) |
|---------------|--------|---------------------|------------------------------|
| Seconds       | 10     | `1732056789`        | 1/second                     |
| Milliseconds  | 13     | `1732056789123`     | 1,000/second                 |
| Microseconds  | 16     | `1732056789123456`  | 1,000,000/second             |
| Nanoseconds   | 19     | `1732056789123456789` | 1 billion/second           |

### Slug Format

The slug includes a hyphen separator at the midpoint:

| Precision | Format | Example Output           | Total Length |
|-----------|--------|--------------------------|--------------|
| 10 (sec)  | 5-5    | `AbCdE-FgHiJ`            | 11 chars     |
| 13 (ms)   | 6-7    | `AbCdEf-GhIjKlM`         | 14 chars     |
| 16 (μs)   | 8-8    | `AbCdEfGh-IjKlMnOp`      | 17 chars     |
| 19 (ns)   | 9-10   | `AbCdEfGhI-JkLmNoPqRs`   | 20 chars     |

**Default: 16 (microseconds) - 17 characters**

### Examples

#### Basic Usage

```sql
-- Default (microseconds precision)
SELECT gen_unique_slug();
-- Result: 'qWeRtYuI-oPasDfGh'

-- Specific precision
SELECT gen_unique_slug(10);   -- seconds: 11 chars
SELECT gen_unique_slug(13);   -- milliseconds: 14 chars
SELECT gen_unique_slug(16);   -- microseconds: 17 chars
SELECT gen_unique_slug(19);   -- nanoseconds: 20 chars
```

#### As Column Default

```sql
CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    slug text DEFAULT gen_unique_slug() UNIQUE
);

INSERT INTO products (name) VALUES ('My Product');
-- slug is automatically generated
```

#### In INSERT Statement

```sql
INSERT INTO products (name, slug)
VALUES ('Another Product', gen_unique_slug(13));
```

## How It Works

### Algorithm

1. Get current timestamp with specified precision
2. Convert each digit (0-9) to a letter using QWERTY-based bucket mapping
3. Randomly select one letter from the bucket for each digit
4. Insert hyphen at midpoint

### Character Buckets (QWERTY Layout)

```
Digit 0: qWeRtY (6 letters)
Digit 1: QwErTy (6 letters)
Digit 2: uIoPa  (5 letters)
Digit 3: UiOpA  (5 letters)
Digit 4: sDfGh  (5 letters)
Digit 5: SdFgH  (5 letters)
Digit 6: jKlZx  (5 letters)
Digit 7: JkLzX  (5 letters)
Digit 8: cVbNm  (5 letters)
Digit 9: CvBnM  (5 letters)
```

**Each bucket contains unique characters** - no overlap between buckets.

### Uniqueness Guarantee

- **Different timestamps = different slugs** (at least one digit differs)
- **Same timestamp = possible collision** (~1 in 10 million with microseconds)

| Precision    | Collision-free if...       |
|--------------|----------------------------|
| seconds      | max 1 insert/second        |
| milliseconds | max 1 insert/millisecond   |
| microseconds | max 1 insert/microsecond   |
| nanoseconds  | max 1 insert/nanosecond    |

## Development

### Project Structure

```
pg_unique_slug/
├── pg_unique_slug.c           # Main C source code
├── pg_unique_slug.control     # Extension metadata
├── sql/
│   └── pg_unique_slug--1.0.sql # SQL installation script
├── test/
│   ├── sql/
│   │   └── basic.sql          # Regression tests
│   └── expected/
│       └── basic.out          # Expected output
├── Makefile
├── Dockerfile
├── docker-compose.yml
├── dev.sh                     # Development helper
└── README.md
```

### Building with Docker

```bash
./dev.sh start     # Start PostgreSQL container
./dev.sh build     # Build extension
./dev.sh install   # Install in database
./dev.sh rebuild   # Build + Install
```

### Running Tests

```bash
./dev.sh test      # Run regression tests
./dev.sh quicktest # Quick manual test
```

## License

MIT License - see LICENSE file for details.

## Author

Fernando Olle

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
