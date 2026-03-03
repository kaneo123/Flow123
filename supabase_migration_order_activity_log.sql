-- Migration: Create order_activity_log table for tracking per-order/per-table history
-- This table stores all staff actions on orders (add/remove items, discounts, park/resume, etc.)
-- History is cleared when an order is completed/paid

create table if not exists public.order_activity_log (
  id uuid primary key default gen_random_uuid(),

  outlet_id uuid not null,
  order_id uuid not null,
  table_id uuid null,              -- optional snapshot (from orders.table_id)
  staff_id uuid null,

  action_type text not null check (
    action_type = any (
      array[
        'item_added',
        'item_removed',
        'discount_applied',
        'discount_removed',
        'voucher_applied',
        'loyalty_applied',
        'order_parked',
        'order_resumed',
        'note_added'
      ]
    )
  ),

  action_description text not null,  -- human readable summary
  meta jsonb null,                   -- optional extra data

  created_at timestamptz not null default now(),

  constraint order_activity_log_outlet_id_fkey
    foreign key (outlet_id) references public.outlets(id) on delete cascade,

  constraint order_activity_log_order_id_fkey
    foreign key (order_id) references public.orders(id) on delete cascade,

  constraint order_activity_log_staff_id_fkey
    foreign key (staff_id) references public.staff(id) on delete set null
);

-- Indexes for efficient queries
create index if not exists idx_order_activity_log_order
  on public.order_activity_log (order_id, created_at);

create index if not exists idx_order_activity_log_outlet
  on public.order_activity_log (outlet_id, created_at);

-- Enable RLS
alter table public.order_activity_log enable row level security;

-- RLS Policy: Allow public access for now (adjust based on your auth requirements)
create policy "Allow public access to order_activity_log"
  on public.order_activity_log
  for all
  using (true)
  with check (true);

-- Comment
comment on table public.order_activity_log is 'Tracks staff actions on orders for per-table history. History is cleared when order status becomes completed/void/refunded.';
