-- Remove the unique_ticket_per_day constraint from the queues table
-- This constraint was preventing users from getting tickets for different services on the same day

ALTER TABLE queues DROP CONSTRAINT IF EXISTS unique_ticket_per_day;

-- Optional: Add a better constraint that only prevents duplicate active tickets
-- This allows users to get tickets for different services after their current ticket is done

-- First, create a partial unique index that only applies to active tickets (waiting or serving)
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_ticket_per_user
ON queues (user_id, queue_date)
WHERE status IN ('waiting', 'serving');

-- This new constraint ensures:
-- 1. User can only have ONE active (waiting/serving) ticket at a time
-- 2. After ticket is done/skipped, user can get another ticket
-- 3. User can have multiple completed tickets for different services on the same day
