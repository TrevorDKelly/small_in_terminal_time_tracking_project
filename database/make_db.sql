CREATE DATABASE time_tracking;

\c time_tracking

CREATE TABLE days (
       day_id  integer GENERATED ALWAYS AS IDENTITY,
       day     date NOT NULL DEFAULT current_date,
       PRIMARY KEY (day_id)
);

CREATE TABLE sessions (
       session_id integer GENERATED ALWAYS AS IDENTITY,
       day_id     integer NOT NULL,
       start_time time NOT NULL DEFAULT current_time,
       end_time   time,
       PRIMARY KEY (session_id),
       CONSTRAINT fk_days FOREIGN KEY (day_id) REFERENCES days (day_id)
         ON DELETE CASCADE
);

INSERT INTO days DEFAULT VALUES;
INSERT INTO sessions (day_id, start_time, end_time)
VALUES (1, CURRENT_TIME, CURRENT_TIME);
