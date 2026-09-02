import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PRODUCTION_APP_ORIGINS = new Set([
  "https://serveflow.app",
  "https://www.serveflow.app",
  Deno.env.get("FRONTEND_ORIGIN") ?? "",
]);

function allowedOrigin(origin: string | null) {
  if (origin === "http://localhost:8080" || (origin && PRODUCTION_APP_ORIGINS.has(origin))) {
    return origin;
  }
  return null;
}

function response(body: Record<string, unknown>, status: number, origin: string | null) {
  const headers = new Headers({ "Content-Type": "application/json", Vary: "Origin" });
  if (origin) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Headers", "Authorization, apikey, content-type, x-client-info");
    headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  }
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (request) => {
  const origin = allowedOrigin(request.headers.get("Origin"));
  if (request.method === "OPTIONS") return response({ ok: true }, 200, origin);
  if (request.method !== "POST") return response({ error: "Method not allowed" }, 405, origin);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return response({ error: "Authentication required" }, 401, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID");
  const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  const razorpayPlanId = Deno.env.get("RAZORPAY_PLAN_ID");

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !razorpayKeyId || !razorpayKeySecret || !razorpayPlanId) {
    console.error("Missing required subscription secrets");
    return response({ error: "Subscription service is not configured" }, 500, origin);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return response({ error: "Authentication required" }, 401, origin);

  let input: { business_id?: unknown };
  try {
    input = await request.json();
  } catch {
    return response({ error: "Invalid JSON body" }, 400, origin);
  }
  const businessId = typeof input.business_id === "string" ? input.business_id : "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(businessId)) {
    return response({ error: "A valid business_id is required" }, 400, origin);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: membership, error: membershipError } = await admin
    .from("business_memberships")
    .select("role")
    .eq("business_id", businessId)
    .eq("user_id", user.id)
    .eq("status", "active")
    .maybeSingle();
  if (membershipError) {
    console.error("Membership lookup failed", membershipError);
    return response({ error: "Unable to validate business access" }, 500, origin);
  }
  if (!membership || !["owner", "manager"].includes(membership.role)) {
    return response({ error: "You do not have permission for this business" }, 403, origin);
  }

  const { data: business, error: businessError } = await admin
    .from("businesses")
    .select("id, name, razorpay_subscription_id, subscription_status, subscription_expires_at")
    .eq("id", businessId)
    .eq("is_deleted", false)
    .maybeSingle();
  if (businessError) {
    console.error("Business lookup failed", businessError);
    return response({ error: "Unable to load business" }, 500, origin);
  }
  if (!business) return response({ error: "Business not found" }, 404, origin);
  // A prior Checkout attempt may have been closed before payment. Reuse the
  // saved Razorpay subscription so a retry does not create a duplicate.
  if (business.razorpay_subscription_id) {
    return response({
      subscription_id: business.razorpay_subscription_id,
      key_id: razorpayKeyId,
      business_id: businessId,
    }, 200, origin);
  }

  const basicAuth = btoa(`${razorpayKeyId}:${razorpayKeySecret}`);
  const razorpayResponse = await fetch("https://api.razorpay.com/v1/subscriptions", {
    method: "POST",
    headers: { Authorization: `Basic ${basicAuth}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      plan_id: razorpayPlanId,
      total_count: 12,
      quantity: 1,
      customer_notify: 1,
      notes: { business_id: businessId, user_id: user.id },
    }),
  });
  if (!razorpayResponse.ok) {
    const detail = await razorpayResponse.text();
    console.error("Razorpay subscription creation failed", razorpayResponse.status, detail);
    return response({ error: "Unable to create Razorpay subscription" }, 502, origin);
  }
  const subscription = await razorpayResponse.json();
  if (typeof subscription.id !== "string") {
    console.error("Razorpay response did not contain a subscription id");
    return response({ error: "Invalid Razorpay response" }, 502, origin);
  }

  const { error: updateError } = await admin.from("businesses").update({
    razorpay_subscription_id: subscription.id,
    razorpay_plan_id: razorpayPlanId,
    razorpay_subscription_created_at: new Date().toISOString(),
  }).eq("id", businessId).is("razorpay_subscription_id", null);
  if (updateError) {
    console.error("Failed to persist subscription", updateError);
    return response({ error: "Subscription created but could not be saved" }, 500, origin);
  }

  return response({
    subscription_id: subscription.id,
    key_id: razorpayKeyId,
    business_id: businessId,
  }, 200, origin);
});
