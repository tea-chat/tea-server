CREATE TABLE todo_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL,
    display_name TEXT NOT NULL,
    joined TIMESTAMP NOT NULL DEFAULT now(),
    bio TEXT
);
