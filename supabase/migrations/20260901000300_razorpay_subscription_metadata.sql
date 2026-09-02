  -- Razorpay metadata for the subscription-creation stage.
  -- Entitlement remains controlled by subscription_status and the future webhook.
  alter table public.businesses
    add column if not exists razorpay_subscription_id text,
    add column if not exists razorpay_plan_id text,
    add column if not exists razorpay_subscription_created_at timestamptz;

  create unique index if not exists businesses_razorpay_subscription_id_idx
    on public.businesses (razorpay_subscription_id)
    where razorpay_subscription_id is not null;
