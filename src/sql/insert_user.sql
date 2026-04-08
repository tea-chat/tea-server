insert into users (display_name, username, bio)
values ($1, $2, $3)
returning *;
