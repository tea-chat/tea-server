insert into users (id, username, display_name, joined, bio)
values ($1, $2, $3, $4, $5)
returning *;
