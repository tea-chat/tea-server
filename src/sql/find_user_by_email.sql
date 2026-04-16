select id, email, password_hash, salt from users
where email = $1;
