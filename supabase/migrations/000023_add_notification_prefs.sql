-- Add Notification Preference Columns
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS notification_transaction BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS notification_marketing BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create Index for FCM Token to speed up push notifications
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token);

-- Comment on columns for clarity
COMMENT ON COLUMN public.profiles.notification_transaction IS 'User preference for transaction alerts (Incoming/Outgoing money)';
COMMENT ON COLUMN public.profiles.notification_marketing IS 'User preference for marketing news and promotions';
COMMENT ON COLUMN public.profiles.fcm_token IS 'Firebase Cloud Messaging Token for Push Notifications';
