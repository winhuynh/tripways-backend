-- ============================================================================
-- Trigger: trg_handle_new_auth_user
-- Feature: User authentication
-- Purpose: Create application profile state after an Auth identity is inserted.
-- Responsibilities: Delegate bootstrap validation and insertion to the internal function.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_handle_new_auth_user ON auth.users;

CREATE TRIGGER trg_handle_new_auth_user
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION admin.handle_new_auth_user();
