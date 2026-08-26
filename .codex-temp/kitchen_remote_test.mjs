const base = process.env.TEST_SUPABASE_URL;
const anonKey = process.env.TEST_ANON_KEY;
const serviceKey = process.env.TEST_SERVICE_KEY;
if (!base || !anonKey || !serviceKey) throw new Error('Missing test environment');

const run = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
const password = `Kitchen-${run}-Aa9!`;
const users = [];
const businesses = [];
const counts = { allowed: 0, denied: 0, invalid: 0, reads: 0, scope: 0 };

async function http(path, { method = 'GET', key = anonKey, token, body, headers = {} } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token || key}`,
      'Content-Type': 'application/json',
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = text; }
  }
  return { ok: response.ok, status: response.status, data };
}

function must(result, label) {
  if (!result.ok) throw new Error(`${label}: HTTP ${result.status} ${JSON.stringify(result.data)}`);
  return result.data;
}

async function createUser(label) {
  const email = `kitchen-${label}-${run}@example.invalid`;
  const created = must(await http('/auth/v1/admin/users', {
    method: 'POST', key: serviceKey,
    body: { email, password, email_confirm: true, user_metadata: { full_name: `Kitchen ${label}` } },
  }), `create ${label}`);
  users.push(created.id);
  const session = must(await http('/auth/v1/token?grant_type=password', {
    method: 'POST', body: { email, password },
  }), `login ${label}`);
  return { id: created.id, token: session.access_token, label };
}

async function rpc(user, name, body) {
  return http(`/rest/v1/rpc/${name}`, { method: 'POST', token: user.token, body });
}

async function service(path, method = 'GET', body, headers = {}) {
  return http(`/rest/v1/${path}`, { method, key: serviceKey, body, headers });
}

async function createBusiness(owner, type, suffix) {
  const result = must(await rpc(owner, 'create_business', {
    p_name: `Kitchen Test ${suffix} ${run}`,
    p_type: type,
    p_business_code: `${suffix}${run}`.replace(/[^A-Z0-9]/gi, '').toUpperCase().slice(-20).padStart(6, 'K'),
    p_slug: `kitchen-${suffix.toLowerCase()}-${run}`,
  }), `create ${type}`);
  businesses.push(result.id);
  return result;
}

async function createStall(owner, businessId, label) {
  return must(await rpc(owner, 'create_stall', {
    p_business_id: businessId, p_name: `Stall ${label} ${run}`, p_slug: `stall-${label.toLowerCase()}-${run}`,
  }), `create stall ${label}`);
}

async function assignStall(owner, businessId, stallId, user, role) {
  must(await rpc(owner, 'assign_stall_staff', {
    p_business_id: businessId, p_stall_id: stallId, p_user_id: user.id, p_role: role,
  }), `assign ${role} to stall`);
}

async function assignRestaurant(owner, businessId, user, role) {
  must(await rpc(owner, 'assign_restaurant_staff', {
    p_business_id: businessId, p_user_id: user.id, p_role: role,
  }), `assign restaurant ${role}`);
}

async function makeOrder(businessId, ownerId, stallId = null) {
  const token = `${run}${Math.random().toString(16).slice(2)}`.replace(/[^a-f0-9]/g, 'a').padEnd(32, 'a').slice(0, 32);
  const qr = must(await service('qr_tokens?select=id', 'POST', {
    business_id: businessId, stall_id: stallId, scope: stallId ? 'stall' : 'business', token,
    status: 'active', created_by: ownerId,
  }, { Prefer: 'return=representation' }), 'insert qr')[0];
  return must(await service('orders?select=*', 'POST', {
    business_id: businessId, stall_id: stallId, qr_token_id: qr.id,
    scope: stallId ? 'stall' : 'business', status: 'received',
    stall_name: stallId ? 'Test Stall' : null, currency: 'INR', tax_percentage: 0,
    subtotal_amount: 100, tax_amount: 0, total_amount: 100,
  }, { Prefer: 'return=representation' }), 'insert order')[0];
}

async function reset(orderId, status) {
  must(await service(`orders?id=eq.${orderId}&select=id,status`, 'PATCH', { status }, { Prefer: 'return=representation' }), `reset ${status}`);
}

async function visible(user, orderId) {
  const rows = must(await http(`/rest/v1/orders?id=eq.${orderId}&select=id,status,stall_id`, { token: user.token }), `read as ${user.label}`);
  return rows.length === 1;
}

async function expectTransition(user, order, from, to, allowed, bucket) {
  await reset(order.id, from);
  const result = await rpc(user, 'update_order_status', { p_order_id: order.id, p_new_status: to });
  if (result.ok !== allowed) {
    throw new Error(`${user.label} ${from}->${to}: expected ${allowed ? 'success' : 'denial'}, got HTTP ${result.status} ${JSON.stringify(result.data)}`);
  }
  counts[bucket]++;
}

async function cleanup() {
  for (const id of businesses.reverse()) {
    await service(`orders?business_id=eq.${id}`, 'DELETE');
    await service(`qr_tokens?business_id=eq.${id}`, 'DELETE');
    await service(`stalls?business_id=eq.${id}`, 'DELETE');
    await service(`businesses?id=eq.${id}`, 'DELETE');
  }
  for (const id of users.reverse()) {
    await http(`/auth/v1/admin/users/${id}`, { method: 'DELETE', key: serviceKey });
  }
}

try {
  const [owner, managerA, kitchenA, cashierA, managerB, restaurantOwner, restaurantManager, restaurantKitchen, restaurantCashier] =
    await Promise.all(['owner', 'manager-a', 'kitchen-a', 'cashier-a', 'manager-b', 'restaurant-owner', 'restaurant-manager', 'restaurant-kitchen', 'restaurant-cashier'].map(createUser));

  const foodCourt = await createBusiness(owner, 'food_court', 'FC');
  const stallA = await createStall(owner, foodCourt.id, 'A');
  const stallB = await createStall(owner, foodCourt.id, 'B');
  await assignStall(owner, foodCourt.id, stallA.id, managerA, 'manager');
  await assignStall(owner, foodCourt.id, stallA.id, kitchenA, 'kitchen');
  await assignStall(owner, foodCourt.id, stallA.id, cashierA, 'cashier');
  await assignStall(owner, foodCourt.id, stallB.id, managerB, 'manager');
  const orderA = await makeOrder(foodCourt.id, owner.id, stallA.id);
  const orderB = await makeOrder(foodCourt.id, owner.id, stallB.id);

  if (await visible(managerA, orderB.id)) throw new Error('Manager A could read Stall B order');
  counts.scope++;
  await expectTransition(managerA, orderB, 'received', 'preparing', false, 'scope');
  if (!(await visible(owner, orderA.id)) || !(await visible(owner, orderB.id))) throw new Error('Owner could not read both Food Court stalls');
  counts.reads += 2;
  await expectTransition(owner, orderB, 'received', 'preparing', true, 'allowed');

  const actors = { owner, manager: managerA, kitchen: kitchenA, cashier: cashierA };
  const transitions = [
    ['received', 'preparing', ['owner', 'manager', 'kitchen']],
    ['preparing', 'ready', ['owner', 'manager', 'kitchen']],
    ['ready', 'completed', ['owner', 'manager', 'cashier']],
    ['received', 'cancelled', ['owner', 'manager', 'cashier']],
    ['preparing', 'cancelled', ['owner', 'manager', 'cashier']],
  ];
  for (const [from, to, allowedRoles] of transitions) {
    for (const [role, actor] of Object.entries(actors)) {
      await expectTransition(actor, orderA, from, to, allowedRoles.includes(role), allowedRoles.includes(role) ? 'allowed' : 'denied');
    }
  }

  const statuses = ['received', 'preparing', 'ready', 'completed', 'cancelled'];
  const validEdges = new Set(transitions.map(([a, b]) => `${a}>${b}`));
  for (const from of statuses) {
    for (const to of statuses) {
      if (validEdges.has(`${from}>${to}`)) continue;
      for (const actor of Object.values(actors)) {
        await expectTransition(actor, orderA, from, to, false, 'invalid');
      }
    }
  }

  const restaurant = await createBusiness(restaurantOwner, 'restaurant', 'RS');
  await assignRestaurant(restaurantOwner, restaurant.id, restaurantManager, 'manager');
  await assignRestaurant(restaurantOwner, restaurant.id, restaurantKitchen, 'kitchen');
  await assignRestaurant(restaurantOwner, restaurant.id, restaurantCashier, 'cashier');
  const restaurantOrder = await makeOrder(restaurant.id, restaurantOwner.id);
  for (const actor of [restaurantOwner, restaurantManager, restaurantKitchen, restaurantCashier]) {
    if (!(await visible(actor, restaurantOrder.id))) throw new Error(`${actor.label} could not read Restaurant order`);
    counts.reads++;
  }
  await expectTransition(restaurantOwner, restaurantOrder, 'received', 'preparing', true, 'allowed');
  await expectTransition(restaurantManager, restaurantOrder, 'received', 'preparing', true, 'allowed');
  await expectTransition(restaurantKitchen, restaurantOrder, 'received', 'preparing', true, 'allowed');
  await expectTransition(restaurantCashier, restaurantOrder, 'ready', 'completed', true, 'allowed');
  await expectTransition(restaurantCashier, restaurantOrder, 'received', 'preparing', false, 'denied');

  console.log(JSON.stringify({ ok: true, counts }));
} finally {
  await cleanup();
  console.log(JSON.stringify({ cleanup: true, businesses: businesses.length, users: users.length }));
}
