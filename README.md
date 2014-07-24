# Text-search with postgres

## Documentation

Postgres text-search has very good documentation
once you understand the basic concepts. I haven't found
a good entry-level introduction as yet.

## TSVector
A postgres type used for search (TextSearch Vector).
Essentially it stores a map/hash/dict/whatever of
word => positions where that word appears. For example:
```
> select to_tsVector('skiing is great fun if you like to ski');
'fun':4 'great':3 'like':7 'ski':1,9
```
See that:
 * The position of each important word is recorded
 * 'skiing' and 'ski' have been recorded as the same word
 * 'ski' has two positions because it is mentioned twice
 * irrelevant words are removed

We'll discuss why/how this happens below.

## TSQuery (Text Search Query)

An expression in the postgres text-search language.

For example, `fat & (rat | cat)` will match documents which refer to fat rats or fat cats.

Examples:
```
> select to_tsquery('fat & (rat | cat)');
'fat' & ( 'rat' | 'cat' )
```

These matches are scored for sorting.
This means that `fat foo bar rat` will match our query,
but produce a lower score than `fat rat` (because the
words are far apart).

## Converting strings to text-search types

There are several approaches to convert a string to a set of lexemes.
Postgres lets you combine the ones it knows, such as:
 * Convert to lowercase
 * Remove `stopwords` (e.g. 'of', 'in', 'the', 'an') as they add little to the query
 * Convert words to their `stem` form (e.g. 'skiing' -> 'ski', 'chewed' -> 'chew')

The default configuration combines each of these (using the English stem forms).

In the case of proper nouns, this can be confusing - `Epping` is not a verb meaning `to ep`, even though `skiing` is a verb for `to ski`.
When searching for proper nouns, you probably want to disable stopword and stem filters.
See `proper_noun_config.sql` for a config which removes the stemmer.
