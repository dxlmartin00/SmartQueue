-- Step 1: Check what constraints exist on the queues table
SELECT conname, contype, pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'queues'::regclass;

-- Step 2: Drop the unique_ticket_per_day constraint if it exists
ALTER TABLE queues DROP CONSTRAINT IF EXISTS unique_ticket_per_day;

-- Step 3: Create a better partial unique index for active tickets only
-- This allows users to have only ONE active ticket at a time
-- But they can get new tickets after their previous ticket is done
DROP INDEX IF EXISTS unique_active_ticket_per_user;

CREATE UNIQUE INDEX unique_active_ticket_per_user
ON queues (user_id, queue_date)
WHERE status IN ('waiting', 'serving');

-- Verify the changes
SELECT conname, contype, pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'queues'::regclass;

-- Also show indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'queues';
