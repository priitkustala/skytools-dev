
create or replace function pgq_node.set_global_watermark(
    in i_queue_name text,
    in i_watermark bigint,
    out ret_code int4,
    out ret_note text)
returns record as $$
-- ----------------------------------------------------------------------
-- Function: pgq_node.set_global_watermark(2)
--
--      Move global watermark on branch/leaf, publish on root.
--
-- Parameters:
--      i_queue_name    - queue name
--      i_watermark     - global tick_id that is processed everywhere.
--                        NULL on root, then local wm is published.
-- ----------------------------------------------------------------------
declare
    this        record;
    _wm         bigint;
    wm_consumer text;
begin
    select node_type, queue_name, worker_name into this
        from pgq_node.node_info
        where queue_name = i_queue_name
        for update;
    if not found then
        select 200, 'Queue' || i_queue_name || ' not found'
          into ret_code, ret_note;
        return;
    end if;

    _wm = i_watermark;
    if this.node_type = 'root' then
        if i_watermark is null then
            select f.ret_code, f.ret_note, f.local_watermark
                into ret_code, ret_note, _wm
                from pgq_node.get_node_info(i_queue_name) f;
            if ret_code <> 200 then
                return;
            end if;
            if _wm is null then
                raise exception 'local_watermark=NULL from get_node_info()?';
            end if;
        elsif i_watermark is null then
            select 500, 'bad usage: wm=null on non-root node'
                into ret_code, ret_note;
            return;
        end if;
    end if;

    -- move watermark on pgq
    if this.node_type in ('root', 'branch') then
        wm_consumer = '.global_watermark';
        perform pgq.register_consumer_at(i_queue_name, wm_consumer, _wm);
    end if;

    if this.node_type = 'root' then
        -- send event downstream
        perform pgq.insert_event(i_queue_name, 'pgq.global-watermark', _wm::text,
                                 i_queue_name, null, null, null);
        -- update root workers pos to avoid it getting stale
        update pgq_node.local_state
            set last_tick_id = _wm
            where queue_name = i_queue_name
                and consumer_name = this.worker_name;
    end if;

    select 200, 'Ok' into ret_code, ret_note;
    return;
end;
$$ language plpgsql security definer;


