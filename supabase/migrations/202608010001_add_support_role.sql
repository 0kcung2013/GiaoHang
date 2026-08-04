-- Support (CSKH) role. Commit this enum value before policies use it.
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'support';
