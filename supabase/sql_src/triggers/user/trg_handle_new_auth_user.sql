-- Trigger: trg_handle_new_auth_user
-- Feature: User authentication
-- Purpose: Create application profile state after an Auth identity is inserted.
-- Responsibilities: Delegate bootstrap validation and insertion to the private function.

drop trigger if exists trg_handle_new_auth_user on auth.users;

create trigger trg_handle_new_auth_user
after insert on auth.users
for each row
execute function private.handle_new_auth_user();
