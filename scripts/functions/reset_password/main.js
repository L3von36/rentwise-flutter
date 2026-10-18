/**
 * RentWise — reset-password function (Node 18 runtime).
 *
 * Lets the workspace OWNER reset an employee's password from the app
 * (Access & roles → Team members → key icon). The client SDK cannot
 * change another user's password — only the server API key can, and it
 * lives HERE, never in the app.
 *
 * Security:
 *   1. The app executes this function with a signed-in session, so
 *      Appwrite injects X-Appwrite-User-Id / X-Appwrite-User-JWT.
 *   2. The JWT is verified against /account — header spoofing is useless.
 *   3. The caller's profiles document must have role "owner".
 *   4. Only then is PATCH /users/{userId}/password called with the API key.
 *
 * Console env vars to set (Function → Settings → Variables):
 *   APPWRITE_API_KEY  — API key with users.read, users.write,
 *                       databases.read, documents.read scopes
 *   AW_ENDPOINT       — (optional, default https://cloud.appwrite.io/v1)
 *   AW_DATABASE_ID    — (optional, default rentwise-db)
 *   AW_PROFILES       — (optional, default profiles)
 */

const ENDPOINT = process.env.APPWRITE_FUNCTION_API_ENDPOINT ||
    process.env.AW_ENDPOINT || 'https://cloud.appwrite.io/v1';
const PROJECT = process.env.APPWRITE_FUNCTION_PROJECT_ID ||
    process.env.APPWRITE_PROJECT_ID || '';
const DATABASE_ID = process.env.AW_DATABASE_ID || 'rentwise-db';
const PROFILES = process.env.AW_PROFILES || 'profiles';
const API_KEY = process.env.APPWRITE_API_KEY || '';

const jsonHeaders = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': PROJECT,
  'X-Appwrite-Key': API_KEY,
};

async function verifyOwner(jwt) {
  // Proves the JWT belongs to a real, active session.
  const res = await fetch(`${ENDPOINT}/account`, {
    headers: { 'X-Appwrite-Project': PROJECT, 'X-Appwrite-JWT': jwt },
  });
  if (!res.ok) return null;
  const user = await res.json();
  if (!user?.$id) return null;
  // Owner check lives in the profiles database.
  const pRes = await fetch(
      `${ENDPOINT}/databases/${DATABASE_ID}/collections/${PROFILES}/documents/${user.$id}`,
      { headers: jsonHeaders });
  if (!pRes.ok) return null;
  const profile = await pRes.json();
  return profile?.role === 'owner' ? user.$id : null;
}

export default async ({ req, res, log }) => {
  if (!API_KEY) {
    log('APPWRITE_API_KEY env var is not set.');
    return res.json({ ok: false, error: 'Function is not configured — set APPWRITE_API_KEY in the console.' }, 500);
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { body = null; }
  }
  const userId = body?.userId;
  const newPassword = body?.newPassword;

  if (!userId || !newPassword || String(newPassword).length < 8) {
    return res.json({ ok: false, error: 'userId and newPassword (min 8 characters) are required.' }, 400);
  }

  const jwt = req.headers['x-appwrite-user-jwt'];
  if (!jwt) {
    return res.json({ ok: false, error: 'Sign in as the workspace owner and run this from the app.' }, 401);
  }

  const ownerId = await verifyOwner(jwt);
  if (!ownerId) {
    log(`Denied: caller is not an owner.`);
    return res.json({ ok: false, error: 'Only the workspace owner can reset passwords.' }, 403);
  }

  const res2 = await fetch(`${ENDPOINT}/users/${encodeURIComponent(userId)}/password`, {
    method: 'PATCH',
    headers: jsonHeaders,
    body: JSON.stringify({ password: String(newPassword) }),
  });
  if (!res2.ok) {
    const detail = await res2.text().catch(() => '');
    log(`Password update failed: ${res2.status} ${detail}`);
    return res.json({ ok: false, error: `Appwrite rejected the new password (${res2.status}).` }, 400);
  }

  log(`Owner ${ownerId} reset password for ${userId}.`);
  return res.json({ ok: true });
};
