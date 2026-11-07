-- Explicit deny also protects credentials if a future change grants table access.
CREATE POLICY customer_wallet_security_no_direct_access
ON private.customer_wallet_security AS RESTRICTIVE FOR ALL TO public
USING (false) WITH CHECK (false);
