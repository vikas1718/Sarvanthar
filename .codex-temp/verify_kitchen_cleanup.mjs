const base = process.env.TEST_SUPABASE_URL;
const key = process.env.TEST_SERVICE_KEY;
const headers = { apikey: key, Authorization: `Bearer ${key}` };
async function del(path) {
  const r = await fetch(`${base}${path}`, { method: 'DELETE', headers });
  if (!r.ok) throw new Error(`DELETE ${path}: ${r.status} ${await r.text()}`);
}

let businesses = await fetch(`${base}/rest/v1/businesses?name=like.Kitchen%20Test*&select=id`, { headers }).then(r => r.json());
for (const business of businesses) {
  await del(`/rest/v1/orders?business_id=eq.${business.id}`);
  await del(`/rest/v1/qr_tokens?business_id=eq.${business.id}`);
  await del(`/rest/v1/stalls?business_id=eq.${business.id}`);
  await del(`/rest/v1/businesses?id=eq.${business.id}`);
}

let usersResponse = await fetch(`${base}/auth/v1/admin/users?per_page=1000`, { headers }).then(r => r.json());
let users = (usersResponse.users || []).filter(u => u.email?.startsWith('kitchen-') && u.email.endsWith('@example.invalid'));
for (const user of users) await del(`/auth/v1/admin/users/${user.id}`);

businesses = await fetch(`${base}/rest/v1/businesses?name=like.Kitchen%20Test*&select=id`, { headers }).then(r => r.json());
usersResponse = await fetch(`${base}/auth/v1/admin/users?per_page=1000`, { headers }).then(r => r.json());
users = (usersResponse.users || []).filter(u => u.email?.startsWith('kitchen-') && u.email.endsWith('@example.invalid'));
if (businesses.length || users.length) throw new Error(`Cleanup incomplete: businesses=${businesses.length}, users=${users.length}`);
console.log(JSON.stringify({ cleanupVerified: true, businesses: 0, users: 0 }));
