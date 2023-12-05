create type check_status as enum ('start', 'success', 'failure');

create table if not exists Peers (
    Nickname varchar primary key,
    Birthday date
);

insert into Peers values ('alexander', '01-01-2001');
insert into Peers values ('dyahdeme', '02-10-2002');
insert into Peers values ('vladimir', '03-12-2000');
insert into Peers values ('danil', '04-14-1999');
insert into Peers values ('george', '05-16-1997');
insert into Peers values ('maksat', '06-20-2000');

create table if not exists Tasks (
    Title varchar primary key,
    ParentTask varchar default null,
    MaxXP integer,
    constraint fk_tasks_parent_task foreign key (ParentTask) references Tasks(Title)
);

insert into Tasks values ('C1_SimpleBashUtils', null, 350);
insert into Tasks values ('C2_string+', 'C1_SimpleBashUtils', 650);
insert into Tasks values ('C3_decimal', 'C2_string+', 350);
insert into Tasks values ('C5_matrix', 'C3_decimal', 200);
insert into Tasks values ('C6_SmartCalc_v1.0', 'C5_matrix', 650);

create table if not exists Checks (
    ID bigint primary key,
    Peer varchar,
    Task varchar,
    Date date,
    constraint fk_checks_peer foreign key (Peer) references Peers(Nickname),
    constraint fk_checks_task foreign key (Task) references Tasks(Title)
);

insert into Checks values (1, 'alexander', 'C5_matrix', '03-19-2023');
insert into Checks values (2, 'vladimir', 'C3_decimal', '03-19-2023');
insert into Checks values (3, 'dyahdeme', 'C1_SimpleBashUtils', '03-01-2023');
insert into Checks values (4, 'danil', 'C6_SmartCalc_v1.0', '03-19-2023');
insert into Checks values (5, 'george', 'C2_string+', '03-19-2022');

create table if not exists P2P (
    ID bigint primary key,
    "Check" bigint,
    CheckingPeer varchar,
    State check_status,
    Time time,
    constraint fk_p2p_check foreign key ("Check") references Checks(ID),
    constraint fk_p2p_checkingpeer foreign key (CheckingPeer) references Peers(Nickname)
);

insert into P2P values (1, 1, 'george', 'start', '13:15');
insert into P2P values (2, 1, 'george', 'success', '13:17');
insert into P2P values (3, 2, 'danil', 'start', '14:15');
insert into P2P values (4, 2, 'danil', 'success', '14:20');
insert into P2P values (5, 3, 'dyahdeme', 'start', '15:15');
insert into P2P values (6, 3, 'dyahdeme', 'success', '15:30');
insert into P2P values (7, 4, 'vladimir', 'start', '16:15');
insert into P2P values (8, 4, 'vladimir', 'success', '16:45');
insert into P2P values (9, 5, 'alexander', 'start', '17:30');

create table if not exists Verter (
    ID bigint primary key,
    "Check" bigint,
    State check_status,
    Time time,
    constraint fk_verter_check foreign key ("Check") references Checks(ID)
);

insert into Verter values (1, 1, 'start', '13:17');
insert into Verter values (2, 1, 'success', '13:20');
insert into Verter values (3, 2, 'start', '14:20');
insert into Verter values (4, 2, 'success', '14:23');
insert into Verter values (5, 3, 'start', '15:30');
insert into Verter values (6, 3, 'success', '15:33');
insert into Verter values (7, 4, 'start', '16:45');
insert into Verter values (8, 4, 'success', '16:50');

create table if not exists TransferredPoints (
    ID bigint,
    CheckingPeer varchar,
    CheckedPeer varchar,
    PointsAmount integer default 1,
    constraint fk_checking_peer_peer foreign key (CheckingPeer) references Peers(Nickname),
    constraint fk_checked_peer_peer foreign key (CheckedPeer) references Peers(Nickname)
);

insert into TransferredPoints values (1, 'george', 'alexander', 1);
insert into TransferredPoints values (2, 'danil', 'vladimir', 1);
insert into TransferredPoints values (3, 'dyahdeme', 'george', 1);
insert into TransferredPoints values (4, 'vladimir','danil', 1);
insert into TransferredPoints values (5, 'alexander', 'dyahdeme', 1);

create table if not exists Friends (
    ID bigint,
    Peer1 varchar,
    Peer2 varchar,
    constraint fk_friends_peer1 foreign key (Peer1) references Peers(Nickname),
    constraint fk_friends_peer2 foreign key (Peer2) references Peers(Nickname)
);

insert into Friends values (1, 'george', 'alexander');
insert into Friends values (2, 'danil', 'alexander');
insert into Friends values (3, 'vladimir', 'alexander');
insert into Friends values (4, 'dyahdeme', 'alexander');
insert into Friends values (5, 'alexander', 'maksat');

create table if not exists Recommendations (
    ID bigint,
    Peer varchar,
    RecommendedPeer varchar,
    constraint fk_recommendations_peer foreign key (Peer) references Peers(Nickname),
    constraint fk_friends_recommended_peer foreign key (RecommendedPeer) references Peers(Nickname)
);

insert into Recommendations values (1, 'george', 'alexander');
insert into Recommendations values (2, 'danil', 'alexander');
insert into Recommendations values (3, 'vladimir', 'alexander');
insert into Recommendations values (4, 'dyahdeme', 'alexander');
insert into Recommendations values (5, 'alexander', null);

create table if not exists XP (
    ID bigint,
    "Check" bigint,
    XPAmount bigint,
    constraint fk_xp_check foreign key ("Check") references Checks(ID)
);

insert into XP values (1, 2, 350);
insert into XP values (2, 3, 300);
insert into XP values (3, 4, 500);
insert into XP values (4, 5, 632);

create table if not exists TimeTracking (
    ID bigint,
    Peer varchar,
    Date date,
    Time time,
    State integer,
    constraint fk_time_tracking_peer foreign key (Peer) references Peers(Nickname)
);

alter table TimeTracking add constraint ch_state check ( State in (1, 2) );

insert into TimeTracking values (1, 'george', '03-18-2023', '13:10', 1);
insert into TimeTracking values (2, 'george', '03-18-2023', '21:15', 2);
insert into TimeTracking values (3, 'alexander', '03-17-2023', '13:10', 1);
insert into TimeTracking values (4, 'alexander', '03-18-2023', '13:10', 2);
insert into TimeTracking values (5, 'dyahdeme', '03-10-2023', '11:10', 1);
insert into TimeTracking values (5, 'dyahdeme', '03-10-2023', '22:10', 2);

create or replace procedure import_from_csv(directory text) as
$$
declare
    str text;
BEGIN
    str:='copy Peers(Nickname, Birthday) from ''' || directory || '/peers.csv'' DELIMITER '','' CSV HEADER;';
    EXECUTE (str);
    str:='copy Tasks(Title, ParentTask, MaxXP) from ''' || directory || '/tasks.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Checks(Id, Peer, Task, Date) from ''' || directory || '/checks.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy P2P(Id, "Check", CheckingPeer, State, Time) from ''' || directory || '/p2p.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Verter(Id, "Check", State, Time) from ''' || directory || '/verter.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy TransferredPoints(Id, CheckingPeer, CheckedPeer, PointsAmount) from ''' || directory || '/transferred_points.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Friends(Id, Peer1, Peer2) from ''' || directory || '/friends.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Recommendations(Id, Peer, RecommendedPeer) from ''' || directory || '/recommendations.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy XP(Id, "Check", XPAmount) from ''' || directory || '/xp.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy TimeTracking(Id, Peer, Date, Time, State) from ''' || directory || '/time_tracking.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
END;
$$
    language plpgsql;

call import_from_csv('/Users/danil/SQL2_Info21_v1.0-0/src/csv');

create or replace procedure export_to_csv(directory text) as
$$
declare
    str text;
BEGIN
    str:='copy Peers(Nickname, Birthday) to ''' || directory || '/peers.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Tasks(Title, ParentTask, MaxXP) to ''' || directory || '/tasks.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Checks(Id, Peer, Task, Date) to ''' || directory || '/checks.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy P2P(Id, "Check", CheckingPeer, State, Time) to ''' || directory || '/p2p.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Verter(Id, "Check", State, Time) to ''' || directory || '/verter.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy TransferredPoints(Id, CheckingPeer, CheckedPeer, PointsAmount) to ''' || directory || '/transferred_points.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Friends(Id, Peer1, Peer2) to ''' || directory || '/friends.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy Recommendations(Id, Peer, RecommendedPeer) to ''' || directory || '/recommendations.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy XP(Id, "Check", XPAmount) to ''' || directory || '/xp.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
    str:='copy TimeTracking(Id, Peer, Date, Time, State) to ''' || directory || '/time_tracking.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE (str);
END;
$$
    language plpgsql;

call export_to_csv('/Users/danil/SQL2_Info21_v1.0-0/src/csv');