create or replace function pgq.version()
returns text as $$
-- ----------------------------------------------------------------------
-- Function: pgq.version(0)
--
--      Returns verison string for pgq.  ATM its SkyTools version
--      that is only bumped when PGQ database code changes.
-- ----------------------------------------------------------------------
begin
    return '3.0devel';
end;
$$ language plpgsql;

