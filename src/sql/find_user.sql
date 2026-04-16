select id, username, display_name, joined, bio from users
where id = $1;
