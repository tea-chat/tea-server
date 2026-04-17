insert into auth_codes (code_hash, user_id, code_challenge, code_challenge_method)
values ($1, $2, $3, $4)
returning user_id, expires_at;
