# Text-search with postgres

## Documentation

Postgres text-search has very good documentation
once you understand the basic concepts. I haven't found
a good entry-level introduction as yet, so this is
my attempt to quickly explain the important bits.

## TSVector
A postgres type used for search (TextSearch Vector).
The builtin function to_tsVector converts a string
to this type.

tsVector stores a map/hash/dict/whatever of
word => positions where that word appears. For example:
```sql
> select to_tsVector('skiing is great fun if you like to ski');
'fun':4 'great':3 'like':7 'ski':1,9
```
See that:
 * The position of each important word is recorded
 * 'skiing' and 'ski' have been recorded as the same word
 * 'ski' has two positions because it is mentioned twice
 * irrelevant words are removed


## GIN and GIST index types

Postgres offers two index types which are suited to
text search: GIN (generalized inverted index) and GIST (Generalized Search Tree).

The documentation goes into detail about which to use when; GIN is faster to read but slower to write.


Unlike most DBMS's, postgres lets you create an index
on the result of a function.
When implementing search you would usually take advantage
of this feature like so:
```
CREATE INDEX "fulltext_index"
ON "text_documents"
USING gin (
  TO_TSVECTOR(body)
);
```

## TSQuery (Text Search Query)

An expression in the postgres text-search language.

For example, `fat & (rat | cat)` will match documents which refer to fat rats or fat cats.

You can use other bits of syntax, too - for instance, `'abs':*` matches any word starting with 'abs'.

If you are using user-supplied input, you might want to try `PLAIN_ToTSQuery` instead.

## Match quality & scoring

You can find out how closely a tsVector matches a tsQuery
by calling `ts_rank_cd(vector, query)`.
This is useful to display relevant matches first.
For instance:
```sql
> select ts_rank_cd(to_tsvector('fat foo bar rat'), to_tsquery('fat & (rat | cat)'));
0.0333333

select ts_rank_cd(to_tsvector('fat rat'), to_tsquery('fat & (rat | cat)'));
0.1
```

## Converting strings to text-search types

There are several approaches to pre-process a string for search.
Postgres lets you combine the ones it knows, such as:
 * Convert to lowercase
 * Remove `stopwords` (e.g. 'of', 'in', 'the', 'an') as they add little to the query
 * Convert words to their `stem` form (e.g. 'skiing' -> 'ski', 'chewed' -> 'chew')

The default configuration combines each of these (using the English stem forms).

In the case of proper nouns, this can be confusing - `Epping` is not a verb meaning `to ep`, even though `skiing` is a verb for `to ski`.
When searching for proper nouns, you probably want to disable stopword and stem filters.
See `proper_noun_config.sql` for a config which removes the stemmer.
