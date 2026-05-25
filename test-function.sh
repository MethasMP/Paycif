#!/bin/bash

# Test script for get-topup-status Edge Function (Local Development)

SUPABASE_URL="http://localhost:54321"
ANON_KEY="your-anon-key-here"

echo "Testing get-topup-status Edge Function..."
echo "URL: $SUPABASE_URL/functions/v1/get-topup-status"
echo ""

# Test 1: Without auth (should fail with 401)
echo "Test 1: Without Authorization header"
curl -s -X GET "$SUPABASE_URL/functions/v1/get-topup-status" | jq .
echo ""

# Test 2: With invalid auth (should fail with 401)
echo "Test 2: With invalid token"
curl -s -X GET "$SUPABASE_URL/functions/v1/get-topup-status" \
  -H "Authorization: Bearer invalid_token" | jq .
echo ""

echo "To test with valid token:"
echo "1. Login in your app"
echo "2. Get JWT token from Supabase"
echo "3. Run:"
echo "curl -X GET $SUPABASE_URL/functions/v1/get-topup-status \\"
echo "  -H \"Authorization: Bearer YOUR_VALID_JWT_TOKEN\""
