CREATE TABLE author (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    surname VARCHAR(255) NOT NULL
);

INSERT INTO author (name, surname)
VALUES 
	('Filip', 'Murlak'),
	('Krzysztof', 'Stencel'),
	('Krzysztof', 'Ciebiera'),
	('Edgar', 'Codd'),
	('Raymond', 'Boyce');
	
CREATE TABLE paper (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(1023) NOT NULL,
    classification VARCHAR(1023) NOT NULL
);

INSERT INTO paper (name, classification)
VALUES
	('Stackless Processing of Streamed Trees', 'Databases'),
	('A Relational Model of Data for Large Shared Data Banks', 'Databases'),
	('SEQUEL: A Structured English Query Language', 'Programming Languages'),
	('How to Match Jobs and Candidates - A Recruitment Support System Based on Feature Engineering and Advanced Analytics.', 'Recommender systems');
	
-- SESSION is also a keyword. To tell SQL that we mean the table name,
-- put it in double quotes. Same applies for WHEN as a keyword and column name.
CREATE TABLE "session" (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "when" TIMESTAMP(0) NOT NULL, -- TIMESTAMP is the DATETIME in Postgres
                                  -- The argument is the precision of seconds. 
	                          -- 0 means 0 after decimal point, so up to a second.
    chair_id INTEGER REFERENCES author NOT NULL
);

CREATE TABLE paper_author (
	author_id INTEGER REFERENCES author NOT NULL,
	paper_id INTEGER REFERENCES paper NOT NULL,
	CONSTRAINT paper_paper_id_author_id_pkey PRIMARY KEY (paper_id, author_id)
);

INSERT INTO paper_author (author_id, paper_id) VALUES
	(1, 1),
	(2, 4),
	(3, 2),
	(4, 3),
	(5, 4);

-- TRIGGER ON INSERT OR UPDATE
-- Chair of the session cannot conduct the lecture.
CREATE TABLE lecture (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "when" TIMESTAMP(0) NOT NULL,
    speaker_id INTEGER NOT NULL,
    paper_id INTEGER UNIQUE NOT NULL,
    session_id INTEGER REFERENCES session NOT NULL,
    CONSTRAINT lecture_speaker_id_session_id_key UNIQUE (speaker_id, session_id),
    CONSTRAINT lecture_speaker_id_paper_id_fkey FOREIGN KEY (speaker_id, paper_id) REFERENCES paper_author(author_id, paper_id)
);

-- Triggers in Postgres must always call a special function that RETURNS TRIGGER.
-- It has access to NEW and OLD special names, that contain the NEW inserted/updated
-- row, and OLD contains the old row in case of an update. Accessing OLD during insert
-- will be a runtime error.
-- The return value will become the row to be inserted or updated.
CREATE OR REPLACE FUNCTION lecture_assert_chair_and_speaker_are_distinct_trgfn() RETURNS TRIGGER AS
$$
DECLARE chair_id INTEGER;
BEGIN
	SELECT s.chair_id INTO chair_id
	  FROM "session" s
	  WHERE id = NEW.session_id;
	
    IF (chair_id = NEW.speaker_id) THEN
      RAISE EXCEPTION 'Lecture with id % defines the session chair as its speaker.', NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note that unlike Oracle we are able to process the data row by row
-- and it will be completely fine.
CREATE TRIGGER lecture_chair_cannot_conduct_lecture_trg
  BEFORE INSERT OR UPDATE OF speaker_id, session_id
  ON lecture
  FOR EACH ROW
EXECUTE PROCEDURE lecture_assert_chair_and_speaker_are_distinct_trgfn();

CREATE OR REPLACE FUNCTION session_assert_chair_and_speaker_are_distinct_trgfn() RETURNS TRIGGER AS
$$
BEGIN
    IF (EXISTS (SELECT 1 FROM lecture l WHERE l.session_id = NEW.id AND l.speaker_id = NEW.chair_id)) THEN
      RAISE EXCEPTION 'Chair % is already a speaker during session %.', NEW.chair_id, NEW.id;
    END IF;
	
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER session_chair_cannot_conduct_lecture_trg
  BEFORE UPDATE OF id, chair_id
  ON "session"
  FOR EACH ROW
EXECUTE PROCEDURE session_assert_chair_and_speaker_are_distinct_trgfn();