-- Add lifecycle columns to notifications table
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS dismissed_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS expires_at   TIMESTAMPTZ DEFAULT NULL;

-- Index for efficient filtering of active notifications
CREATE INDEX IF NOT EXISTS idx_notifications_active
  ON notifications (id_senior, dismissed_at, expires_at);
