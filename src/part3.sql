-- 1

DROP FUNCTION IF EXISTS fnc_transferred_points();

CREATE OR REPLACE FUNCTION fnc_transferred_points()
    RETURNS TABLE (Peer1 varchar, Peer2 varchar, Points_Amount integer)
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (LEAST(tp1.checkingpeer, tp1.checkedpeer), GREATEST(tp1.checkingpeer, tp1.checkedpeer))
       tp1.checkingpeer AS Peer1,
       tp1.checkedpeer AS Peer2,
       CAST(COALESCE(SUM(tp1.pointsamount), 0) -
       COALESCE(SUM(tp2.pointsamount), 0) AS integer) AS Points_Amount
    FROM TransferredPoints tp1
    LEFT JOIN TransferredPoints tp2
      ON tp1.checkingpeer = tp2.checkedpeer AND
         tp1.checkedpeer = tp2.checkingpeer
    GROUP BY tp1.checkingpeer, tp1.checkedpeer;
END
$$ LANGUAGE plpgsql;

SELECT *
FROM fnc_transferred_points();

-- 2

DROP FUNCTION IF EXISTS fnc_checks_task_xp();

CREATE OR REPLACE FUNCTION fnc_checks_task_xp()
    RETURNS TABLE (Peer varchar, Task text, XP bigint)
AS $$
BEGIN
    RETURN QUERY
    SELECT ch.peer, SUBSTRING(ch.task FROM '^[^_]+'), x.xpamount
    FROM checks ch
    JOIN xp x on ch.id = x."Check"
    ORDER BY 1;
END
$$ LANGUAGE plpgsql;

SELECT *
FROM fnc_checks_task_xp();

 -- 3

DROP FUNCTION IF EXISTS fnc_get_campus_stayers(date);

CREATE OR REPLACE FUNCTION fnc_get_campus_stayers(day date)
    RETURNS TABLE (Peer varchar)
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT peers.peer as PeerName
    FROM (
        SELECT tt.peer as peer, tt.state
        FROM timetracking tt
        WHERE tt.date = day
            AND tt.peer NOT IN (
                SELECT t.peer
                FROM timetracking t
                WHERE date = day
                GROUP BY t.peer
                HAVING COUNT(*) % 2 = 0
            )
    ) AS peers
    WHERE peers.state = 1;

END
$$ LANGUAGE plpgsql;

SELECT *
FROM fnc_get_campus_stayers('2023-03-18');

-- 4

DROP PROCEDURE IF EXISTS pr_change_prp(refcursor);

CREATE PROCEDURE pr_change_prp(INOUT answer REFCURSOR)
AS
$BODY$
    BEGIN
    OPEN answer FOR
        (SELECT nickname as peer, (COALESCE(increase, 0) - COALESCE(decrease, 0)) AS pointschange
         FROM peers
                  LEFT JOIN
              (SELECT checkingpeer, SUM(pointsamount) AS increase
               FROM transferredpoints
               GROUP BY checkingpeer) AS t ON checkingpeer = peers.nickname
                  LEFT JOIN
              (SELECT checkedpeer, SUM(pointsAmount) AS decrease
               FROM transferredpoints
               GROUP BY checkedpeer) AS b ON checkedpeer = peers.nickname
         ORDER BY pointschange DESC);
    END;
$BODY$
    LANGUAGE plpgsql;

BEGIN;
CALL pr_change_prp('answer');
FETCH ALL IN "answer";
COMMIT;

-- 5

DROP PROCEDURE IF EXISTS pr_change_prp_custom(refcursor);

CREATE PROCEDURE pr_change_prp_custom(INOUT answer REFCURSOR)
AS
$BODY$
    BEGIN
    OPEN answer FOR
        (SELECT nickname as peer, (COALESCE(increase, 0) - COALESCE(decrease, 0)) AS pointschange
         FROM peers
                  LEFT JOIN
              (SELECT peer1, SUM(points_amount) AS increase
               FROM fnc_transferred_points()
               GROUP BY peer1) AS t ON peer1 = peers.nickname
                  LEFT JOIN
              (SELECT peer2, SUM(points_amount) AS decrease
               FROM fnc_transferred_points()
               GROUP BY peer2) AS b ON peer2 = peers.nickname
         ORDER BY pointschange DESC);
    END;
$BODY$
    LANGUAGE plpgsql;

BEGIN;
CALL pr_change_prp_custom('answer');
FETCH ALL IN "answer";
COMMIT;

-- 6

DROP PROCEDURE IF EXISTS pr_most_popular_task(refcursor);

CREATE PROCEDURE pr_most_popular_task(INOUT answer REFCURSOR)
AS
$BODY$
    BEGIN
    OPEN answer FOR
        (SELECT date, task
        FROM (
            SELECT date, task, COUNT(*) as task_count,
                   RANK() OVER (PARTITION BY date ORDER BY COUNT(*) DESC) AS rank
            FROM checks
            GROUP BY date, task
        ) t
        WHERE rank = 1
        ORDER BY date DESC);
    END;
$BODY$
    LANGUAGE plpgsql;

BEGIN;
CALL pr_most_popular_task('answer');
FETCH ALL IN "answer";
COMMIT;

-- 7

DROP PROCEDURE IF EXISTS pr_block_done CASCADE;

CREATE PROCEDURE pr_block_done(IN block varchar, IN answer refcursor)
AS
$BODY$
    BEGIN
    OPEN answer FOR
        (
            with tmp as (select Title from tasks where Title ~ ('' || block || '')),
                    tmp2 as (select checks.peer, checks.task, checks.date, xp.xpamount
                             from checks join XP on checks.ID = XP."Check"
                             where checks.Task ~ ('' || block || '')),
                    tmp3 as (select nickname, tmp.Title, XPAmount
                             from peers
                                      cross join tmp
                                      left outer join tmp2 on tmp2.task = tmp.Title
                                                    and peers.nickname = tmp2.peer),
                    tmp4 as (select Nickname
                             from tmp3
                             except
                             select Nickname
                             from tmp3
                             where XPAmount is null)
              select Nickname, max(date) as Day
              from tmp4 join tmp2 on tmp2.Peer = Nickname
              group by Nickname
              order by Day desc
        );
    END;
$BODY$
    LANGUAGE plpgsql;

BEGIN;
CALL pr_block_done('C', 'answer');
FETCH ALL IN "answer";
COMMIT;

-- 8

DROP PROCEDURE IF EXISTS find_most_recommend_peer CASCADE;

CREATE OR REPLACE PROCEDURE find_most_recommend_peer(IN answer refcursor) AS $BODY$
    BEGIN
        OPEN answer FOR
            WITH tt AS
                (SELECT Peer1, RecommendedPeer, COUNT(*) count
                FROM friends
                JOIN recommendations ON Peer2 = Peer
                WHERE Peer1 != RecommendedPeer
                GROUP BY Peer1, RecommendedPeer
                ORDER BY Peer1),
            max_count AS (SELECT Peer1, MAX(count) AS max
            FROM tt
            GROUP BY Peer1)

            SELECT t.Peer1 Peer,
            t.RecommendedPeer
            FROM tt t
            JOIN max_count m ON t.Peer1 = m.Peer1
            AND t.count = m.max;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL find_most_recommend_peer('answer');
FETCH ALL IN "answer";
END;

-- 9

DROP PROCEDURE IF EXISTS pr_two_blocks_start_percentage CASCADE;

CREATE OR REPLACE PROCEDURE pr_two_blocks_start_percentage(IN result_set refcursor, block1 varchar, block2 varchar)
    as $BODY$
    DECLARE
        total_rows int;
    BEGIN
        SELECT COUNT(*) INTO total_rows from peers;
        OPEN result_set FOR
            WITH started1 AS (
                SELECT DISTINCT c.peer
                from checks c
                WHERE c.task ~ ('' || block1 || '')
            ), started2 AS (
                SELECT DISTINCT c.peer
                from checks c
                WHERE c.task ~ ('' || block2 || '')
            )
            SELECT ROUND((COUNT(s1.peer)::NUMERIC / total_rows::NUMERIC) * 100) as StartedBlock1,
                   ROUND((COUNT(s2.peer)::NUMERIC / total_rows::NUMERIC) * 100) as StartedBlock2,
                   ROUND((COUNT(CASE WHEN s1.peer = s2.peer AND s2.peer IS NOT NULL THEN 1 END)::NUMERIC / total_rows::NUMERIC) * 100) as StartedBothBlocks,
                   ROUND(((total_rows - (COUNT(s2.peer) + COUNT(s1.peer) - COUNT(CASE WHEN s1.peer = s2.peer AND s2.peer IS NOT NULL THEN 1 END)))::NUMERIC / total_rows::NUMERIC) * 100) as DidntStartAnyBlock
            FROM started1 s1
            FULL JOIN started2 s2 ON s1.peer = s2.peer;

    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_two_blocks_start_percentage('my_cursor', 'C', 'CPP');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 10

DROP PROCEDURE IF EXISTS pr_birthday_checks CASCADE;

CREATE OR REPLACE PROCEDURE pr_birthday_checks(IN result_set refcursor)
    as $BODY$
    BEGIN
        OPEN result_set FOR

            SELECT CASE
                WHEN COUNT(*) = 0 THEN 0
                    ELSE ROUND(COUNT(CASE WHEN p.state = 'success' and (v.state = 'success' or v.state is NULL) THEN 1 END)::numeric / COUNT(*)::numeric * 100)
                END as SuccessfulChecks,
                CASE
                    WHEN COUNT(*) = 0 THEN 0
                    ELSE 100 - ROUND(COUNT(CASE WHEN p.state = 'success' and (v.state = 'success' or v.state is NULL) THEN 1 END)::numeric / COUNT(*)::numeric * 100)
                END as UnsuccessfulChecks
                 FROM checks c
            JOIN p2p p on c.id = p."Check" and (p.state = 'success' or p.state = 'failure')
            LEFT JOIN verter v on c.id = v."Check" and (v.state = 'success' or v.state = 'failure' or v.state is NULL)
            JOIN peers p2 on c.peer = p2.nickname
            and EXTRACT(MONTH FROM c.date) = EXTRACT(MONTH FROM p2.birthday)
            AND EXTRACT(DAY FROM c.date) = EXTRACT(DAY FROM p2.birthday)
    ;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_birthday_checks('my_cursor');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;


-- 11

DROP PROCEDURE IF EXISTS pr_ssf CASCADE;

CREATE OR REPLACE PROCEDURE pr_ssf(IN result_set refcursor, task1 varchar, task2 varchar, task3 varchar)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            WITH successes as (
                SELECT *
                    FROM checks c
                JOIN p2p p on c.id = p."Check" and (p.state = 'success')
                LEFT JOIN verter v on c.id = v."Check" and (v.state = 'success' or v.state is NULL)
                JOIN peers p2 on c.peer = p2.nickname
            )
                SELECT nickname
                    FROM successes s1
                WHERE s1.task = task1
            INTERSECT
                SELECT nickname
                    FROM successes s2
                WHERE s2.task = task2
            EXCEPT
                SELECT nickname
                    FROM successes s3
                WHERE s3.task = task3;

    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_ssf('my_cursor', 'C5_matrix', 'C3_decimal', 'C1_SimpleBashUtils');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 12

DROP PROCEDURE IF EXISTS pr_task_hierarchy CASCADE;

CREATE OR REPLACE PROCEDURE pr_task_hierarchy(IN result_set refcursor, current_task varchar)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            WITH RECURSIVE task_hierarchy as (
                SELECT t.title, 0 AS preceding_tasks
                FROM tasks t
                WHERE parenttask IS NULL

                UNION ALL

                SELECT t.title, th.preceding_tasks + 1
                FROM tasks t
                JOIN task_hierarchy th ON t.parenttask = th.title
            )
            SELECT *
            FROM task_hierarchy;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_task_hierarchy('my_cursor', 'C1_SimpleBashUtils');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 13

DROP PROCEDURE IF EXISTS pr_lucky_days CASCADE;

CREATE OR REPLACE PROCEDURE pr_lucky_days(IN result_set refcursor, N int)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            WITH consecutive_success AS (
                SELECT c.date, p.time, p.state,
                       ROW_NUMBER() OVER (ORDER BY c.date, p.time) AS row_number
                FROM checks c
                JOIN p2p p on c.id = p."Check" and (p.state = 'success')
                LEFT JOIN verter v on c.id = v."Check" and (v.state = 'success' or v.state is NULL)
            ),
            consecutive_counts AS (
                SELECT date, COUNT(*) AS consecutive_success_count
                FROM (
                    SELECT date, time, state,
                           ROW_NUMBER() OVER (ORDER BY date, time) AS row_number,
                           ROW_NUMBER() OVER (PARTITION BY date ORDER BY time) - row_number AS consecutive_group
                    FROM consecutive_success
                ) AS subquery
                WHERE state = 'success'
                GROUP BY date, consecutive_group
            )
            select date from (
            SELECT date, MAX(consecutive_success_count) AS max_consecutive
            FROM consecutive_counts
            GROUP BY date) as m
            where max_consecutive >= N;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_lucky_days('my_cursor', 2);
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 14

DROP PROCEDURE IF EXISTS pr_max_xp_peer CASCADE;

CREATE OR REPLACE PROCEDURE pr_max_xp_peer(IN result_set refcursor)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            SELECT xp_sums.peer, xp
                FROM (
                    SELECT c.peer as peer, SUM(xpamount) as xp
                    FROM xp
                        JOIN checks c on c.id = xp."Check"
                    GROUP BY c.peer
                ) as xp_sums
            ORDER BY xp DESC
            LIMIT 1;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_max_xp_peer('my_cursor');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 15

DROP PROCEDURE IF EXISTS pr_came_n_before CASCADE;

CREATE OR REPLACE PROCEDURE pr_came_n_before(IN result_set refcursor, N int, given_datetime timestamp)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            SELECT peer
                FROM timetracking
            WHERE CONCAT(date, ' ', time)::timestamp < given_datetime and state = 1
            GROUP BY peer
            HAVING COUNT(*) >= N;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_came_n_before('my_cursor', 1, '2023-03-11 13:20:00');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 16

DROP PROCEDURE IF EXISTS pr_left_recently CASCADE;

CREATE OR REPLACE PROCEDURE pr_left_recently(IN result_set refcursor, M int, N int)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            SELECT peer FROM (
                SELECT peer, COUNT(date) as count
                FROM timetracking
                WHERE date >= current_date - interval '1 day' * N and state = 2
                GROUP BY peer) as pc
            where count > M;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_left_recently('my_cursor', 1, 5);
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;

-- 17

DROP PROCEDURE IF EXISTS pr_early_entry_p CASCADE;

CREATE OR REPLACE PROCEDURE pr_early_entry_p(IN result_set refcursor)
    as $BODY$
    BEGIN
        OPEN result_set FOR
            SELECT k.m as Month,  ROUND(early::numeric / whole::numeric * 100) as EarlyEntries
            FROM (
                SELECT to_char(date, 'Month') as m, COUNT(peer) as whole
                FROM timetracking
                JOIN peers p on p.nickname = timetracking.peer
                where state = 1 and to_char(p.birthday, 'Month') = to_char(date, 'Month')
                GROUP BY to_char(date, 'Month')) as k
            JOIN (
                SELECT to_char(date, 'Month') as m, COUNT(peer) as early
                FROM timetracking
                JOIN peers p on p.nickname = timetracking.peer
                where state = 1 and to_char(p.birthday, 'Month') = to_char(date, 'Month') and time < '12:00:00'
                GROUP BY to_char(date, 'Month')) as p
            ON k.m = p.m;
    END
$BODY$ LANGUAGE plpgsql;

BEGIN;
CALL pr_early_entry_p('my_cursor');
FETCH ALL IN "my_cursor";
CLOSE my_cursor;
COMMIT;