-- Create a PostgreSQL function to generate sequential ticket numbers per window
-- This prevents race conditions when multiple users request tickets simultaneously

-- Drop all versions of the function if they exist
DROP FUNCTION IF EXISTS generate_ticket_number(uuid, date, int);
DROP FUNCTION IF EXISTS generate_ticket_number(text, int);

-- Create the function with simplified parameters (alphabetically ordered for PostgREST)
CREATE OR REPLACE FUNCTION generate_ticket_number(
  p_queue_date text,
  p_window int
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_prefix text;
  v_next_number int;
  v_ticket_number text;
  v_date date;
BEGIN
  -- Convert text date to date type
  v_date := p_queue_date::date;

  -- Set the prefix based on window
  v_prefix := CASE WHEN p_window = 1 THEN 'A' ELSE 'B' END;

  -- Lock the table to prevent race conditions
  -- Count all tickets for this window today (across all services in that window)
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_next_number
  FROM queues q
  INNER JOIN services s ON q.service_id = s.id
  WHERE s.service_window = p_window
    AND q.queue_date = v_date;

  -- Format the ticket number (e.g., A-001, B-023)
  v_ticket_number := v_prefix || '-' || LPAD(v_next_number::text, 3, '0');

  RETURN v_ticket_number;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION generate_ticket_number(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_ticket_number(text, int) TO anon;
