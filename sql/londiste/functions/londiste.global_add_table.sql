
create or replace function londiste.global_add_table(
    in i_queue_name     text,
    in i_table_name     text,
    out ret_code        int4,
    out ret_note        text)
as $$
-- ----------------------------------------------------------------------
-- Function: londiste.global_add_table(2)
--
--      Register table on Londiste set.
--
--      This means its available from root, events for it appear
--      in queue and nodes can attach to it.
--
-- Called by:
--      on root - londiste.local_add_table()
--      elsewhere - londiste consumer when receives new table event
--
-- Returns:
--      200 - Ok
--      400 - No such set
-- ----------------------------------------------------------------------
declare
    fq_table_name text;
begin
    fq_table_name := londiste.make_fqname(i_table_name);

    perform 1 from pgq_node.node_info where queue_name = i_queue_name;
    if not found then
        select 400, 'No such set: ' || i_queue_name into ret_code, ret_note;
        return;
    end if;

    perform 1 from londiste.table_info where queue_name = i_queue_name and table_name = fq_table_name;
    if found then
        select 200, 'OK, already added: ' || fq_table_name into ret_code, ret_note;
        return;
    end if;

    insert into londiste.table_info (queue_name, table_name)
        values (i_queue_name, fq_table_name);
    select 200, 'OK' into ret_code, ret_note;
    return;
end;
$$ language plpgsql strict;

