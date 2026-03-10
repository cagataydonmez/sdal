BEGIN;

DROP INDEX IF EXISTS idx_connection_requests_sender_status;
DROP INDEX IF EXISTS idx_connection_requests_receiver_status;
DROP INDEX IF EXISTS idx_connection_requests_sender_receiver;
DROP TABLE IF EXISTS connection_requests;

COMMIT;
