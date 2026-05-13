select id, email, password_hash from users
where email = $1;
