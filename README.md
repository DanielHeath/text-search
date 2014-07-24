# Text-search with postgres

Postgres text-search has very detailed documentation
which is fantastic if you're trying to debug something
wierd but less helpful if you're trying to learn how
to use it.

I haven't found a good entry-level
introduction yet, so this is my attempt to quickly
explain the important bits.

## Alternatives

### LIKE queries

There are two options here:
 * '%TERM%', which is *very* slow.
 * 'TERM%', which only works for prefix matching (users have to type in the first word of the document to find it).

### MYSQL

Mysql text-search only works with MyISAM tables.

This is unfortunate as MyISAM is basically broken (no transactions/FKs).

### External search (Sphinx, SOLR, Elasticsearch, etc)

Any of these will provide better
quality search with more configuration parameters.

However, adding new pieces to your stack isn't a decision to take lightly.

A few of the chores you'll face:
 * Copy your data over when you set it up
 * Copy new data over whenever it changes
 * Come up with a secure production configuration
 * Add it to your server provisioning scripts
 * Add it to your developer setup instructions
 * Add it to your CI nodes
 * Forward its logs to your log aggregator
 * Setup newrelic/nagios integration
 * Figure out what to do when it fails & train your on-call staff to do it
 * Get woken up when ops can't fix it at night
 * Train other devs in it (have you tried reading the ElasticSearch docs?)

I'm sure I've forgotten some important bits here.
The core idea is that it's a lot of work to
add something like elasticsearch to your stack.

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

## GIN and GIST indexes

Postgres offers two index types which are suited to
text search: GIN (generalized inverted index) and
GIST (Generalized Search Tree).

The documentation goes into detail about which to use
when; GIN is faster to read but slower to write.

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

You can then query like so:
```
select * from text_documents
where TO_TSQUERY('my query') @@ TO_TSVECTOR(body)
```
and it'll use the index to return only rows which match.

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

## Where to put the search stuff

99% of the code you'll write if you use postgres text-search
is postgres specific, and looks really wierd embedded in ruby.

Additionally, it's easy to accidentally change it so that
the index no longer applies, causing search performance
to plummet.

In my current project I use RSpec to test that search
works correctly. However, the only code in class under test is `find_by_sql ['select * from text_search(?, ?, ?)', query, per_page, page_number]`

I originally put the search SQL in a model scope.
However, I often had to write a migration to maintain
the index when I changed the query.
As a result, I moved the query into the migration
as a stored procedure (so far this has worked well for me).
