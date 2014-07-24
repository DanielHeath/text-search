--
-- Sometimes (e.g. suburb names) you don't want
-- postgres to stem the words (`Epping` is not
-- similar to `ep`).
-- To do this, you'll need to setup an alternative
-- search configuration - see below.
-- This version is a copy of the `simple` config
-- but does not also copy the stemmer.
--
-- To use it, replace
-- TO_TSQUERY(... with TO_TSQUERY('proper_noun', ...
-- TO_TSVECTOR(... with TO_TSVECTOR('proper_noun', ...
--

CREATE TEXT SEARCH DICTIONARY public.proper_noun (
    TEMPLATE = pg_catalog.simple
);

CREATE TEXT SEARCH CONFIGURATION proper_noun (
    COPY = simple
);

ALTER TEXT SEARCH CONFIGURATION
    proper_noun
ALTER MAPPING
REPLACE
    simple
WITH
    proper_noun;
