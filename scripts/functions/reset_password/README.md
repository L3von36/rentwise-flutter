# reset-password Appwrite Function

One-time setup that enables **Owner → Access & roles → Team members →
Reset password** in the app. The client SDK can never change another
user's password — this small function holds the server API key safely
on Appwrite's servers and verifies the caller is the workspace owner
before touching anything.

## Deploy (Appwrite Console, ~3 minutes)

1. Appwrite Console → your `rentwise` project → **Functions → Create function**.
   - Name: `reset-password` (must match exactly — the app calls this id)
   - Runtime: **Node 18** (or newer)
   - Execution permission: **Users** (any signed-in user may execute;
     the function itself verifies the owner role)
2. Open the function → **Deployments → Create deployment**:
   - Commands: `install: npm install` → **leave empty** (no deps),
     entrypoint: `src/main.js`
   - Paste the full contents of `main.js` as the code.
3. **Settings → Variables** → add:
   - `APPWRITE_API_KEY` — an API key with scopes:
     `users.read`, `users.write`, `databases.read`, `documents.read`
4. **Deployments → Activate** the new deployment.

Done — the in-app Reset password action works immediately, with no app
update needed.

## What it does

1. Executes only with a signed-in session (Appwrite injects the user's
   JWT — the function verifies it against `/accounts`, so headers
   cannot be spoofed).
2. Reads the caller's `profiles` document — must be `role: owner`.
3. Calls `PATCH /users/{userId}/password` with the API key.

Anything else (employees, strangers, wrong JWT) is refused with 403 and
logged. Every reset performed from the app is also written to the
RentWise activity log by the app itself.
