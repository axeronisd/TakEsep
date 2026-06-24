ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE couriers ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN user_profiles.terms_accepted IS 'Tracks whether the customer/user has accepted the general Public Offer and Privacy Policy.';
COMMENT ON COLUMN couriers.terms_accepted IS 'Tracks whether the courier has accepted the general Public Offer and Privacy Policy.';
