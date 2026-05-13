select user_id from sessions
where token_hash = $1;
