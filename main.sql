-- setup the table
drop table if exists text_documents;
CREATE TABLE text_documents (
    name character varying(15) not null,
    body text not null
);

-- add some data
insert into text_documents ( name, body ) values (
  'quick brown fox',
  'The Quick Brown Fox Jumped Over The Lazy Dog'
);

insert into text_documents ( name, body ) values (
  'The Raven',
  'Once upon a midnight dreary, while I pondered weak and weary,
Over many a quaint and curious volume of forgotten lore,
While I nodded, nearly napping, suddenly there came a tapping,
As of some one gently rapping, rapping at my chamber door.'
);

insert into text_documents ( name, body ) values (
  'Childrens Rhymes',
  'The fat cat sat on the mat'
);

-- I've used stored procedures here.
-- Lots of people will tell you not to use them.
-- I think they are the right choice when they
-- deal with things that are internal to the DB.
CREATE OR REPLACE FUNCTION search_term_to_tsquery(query text)
RETURNS tsquery AS $$
BEGIN
  RETURN
    -- This escapes quotes in the input query.
    -- Because the quote handling is specific to PG
    -- it belongs in the db and not the app.

    -- The TSQUERY syntax is pretty involved
    -- and you should read the detailed documentation
    -- to understand what fits your app best.
    TO_TSQUERY(
      '''' ||
      regexp_replace(query, '''', '', 'gi') ||
      ''':*'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Rather than defining the vector format in both
-- the query and the index, I've created this
-- function & used it in both places. --
CREATE OR REPLACE FUNCTION doc_to_tsvector(name text, body text)
RETURNS tsvector AS $$
BEGIN
  RETURN
    SetWeight(TO_TSVECTOR(name), 'A') ||
    SetWeight(TO_TSVECTOR(body), 'D');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

drop index if exists "fulltext_index";
CREATE INDEX "fulltext_index"
ON "text_documents"
USING gin (
  doc_to_tsvector(name, body)
);

DROP FUNCTION IF EXISTS text_search(query text, per_page int, page_number int);

-- The big one: Encapsulate all the search behavior into one function. --
CREATE OR REPLACE FUNCTION text_search(query text, per_page int, page_number int)
RETURNS table (
    name varchar(15),
    body text,
    score real
) AS $$
BEGIN
  RETURN QUERY
    SELECT
      text_documents.name,
      text_documents.body,
      ts_rank_cd(
        doc_to_tsvector(text_documents.name, text_documents.body),
        search_term_to_tsquery(query)
      ) as score
    FROM
      text_documents
    WHERE (
      doc_to_tsvector(text_documents.name, text_documents.body)
      @@
      search_term_to_tsquery(query)
    )
    ORDER BY
      -- Sort by match quality --
      score desc
    LIMIT
      per_page
    OFFSET
      per_page * (page_number - 1);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

select * from text_search('fox', 10, 1);
