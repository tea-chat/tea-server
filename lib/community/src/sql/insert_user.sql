insert into users (username, display_name, email, password_hash, bio)
values ($1, $2, $3, $4, $5)
returning id, username, display_name, joined, bio;
