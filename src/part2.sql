create or replace procedure add_p2p_check(checking_peer varchar,
                                            checked_peer varchar,
                                            task_name varchar,
                                            status check_status,
                                            check_time time without time zone) as $$
begin
   if status = 'start' then
       insert into checks values ((select max(id) + 1 from checks), checked_peer, task_name, current_date);
       insert into p2p values ((select max(id) + 1 from p2p), (select max(id) from checks), checking_peer, status, check_time);
    else
       insert into p2p
       values((select max(id) + 1 from p2p),
              (select checks.id from checks
                                where checks.peer = checked_peer and
                                      task = task_name
              limit 1),
              checking_peer, status, check_time);
   end if;
end;
    $$ language plpgsql;

call add_p2p_check('danil', 'alexander', 'C2_string+', 'start', '19:10:00');

create or replace procedure add_verter_check(checking_peer varchar,
                                             task_name varchar,
                                             status check_status,
                                             check_time time without time zone) as $$
begin
    insert into verter values ((select max(id) + 1 from verter),
                               (select "Check" from p2p
                                join checks on checks.id = "Check"
                                    where p2p.state = 'success'
                                        and checks.task = task_name
                                        and p2p.checkingpeer = checking_peer
                                order by time desc
                                limit 1), status, check_time);
end;
$$ language plpgsql;

call add_verter_check('danil', 'C2_string+', 'success', '19:12:00');

create or replace function fnc_transfer_points() returns trigger as $$
    begin
        update transferredpoints
        set pointsamount = pointsamount + 1
        where checkingpeer = new.checkingpeer and
              checkedpeer = (select peer from checks order by id desc limit 1);
        return null;
    end;
$$ language plpgsql;

create or replace trigger transfer_points
    after insert on p2p
    for each row when (new.state = 'success') execute procedure fnc_transfer_points();

call add_p2p_check('danil', 'vladimir', 'C3_decimal', 'start', '19:10:00');
call add_p2p_check('danil', 'vladimir', 'C3_decimal', 'success', '19:10:00');

create or replace function fnc_correct_xp_amount_check() returns trigger as $$
    begin
      if (select tasks.MaxXP > new.XPAmount from tasks
          inner join checks on tasks.title = checks.task where checks.id = NEW."Check") THEN
        return null;
      end if;
      if (select count(*) = 0 from checks
            inner join p2p on checks.id = p2p."Check"
            left join verter on checks.id = verter."Check"
            where checks.id = new."Check"
              and p2p.state = 'Success') then
          return null;
      end if;
    end;
        $$ language plpgsql;

create or replace trigger correct_check
    before insert on XP
    for each row execute procedure fnc_correct_xp_amount_check();

insert into XP values (5, 2, 250);