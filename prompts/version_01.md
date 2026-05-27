Act as an expert backend engineer. We are building a lightweight Python backend using FastAPI that will be deployed to Google Cloud Run. 

### Context & Strategy
- The primary goal is keeping infrastructure costs as close as possible to $0.00 by utilizing the free tiers of Google Cloud Run and Neon Postgres.
- We already have a lightweight 'Dockerfile' in the root directory utilizing `python:3.11-slim`. Keep it lightweight. Let me know if anything is missing.
- We have a Neon Postgres 17 database provisioned to store users.
- In later phases, we will integrate Cloudflare CDN and Cloudflare R2 for user file uploads. We will also connect to an AI API. Design the system components cleanly and state-independently

### Initial Feature Scope
Implement a unified FastAPI application that achieves exactly one core flow: Secure User Sign-up, Login, and Session management.
1. Google OAuth 2.0 ("Login with Google"): Standard workflow using asynchronous requests (`httpx`).
2. Traditional Credentials (Username/Email + Password): Secure registration and authentication using a modern hashing library like `passlib` or `bcrypt`.

### Technical Specifications
1. Database Integration: 
   - Set up an ORM (like SQLAlchemy or Tortoise-ORM) to manage a 'users' table in our Neon database. 
   - The user schema must support both authentication types: email, hashed_password (nullable for Google-only signups), auth_provider ("local" or "google"), and standard metadata.
   - Use an environment variable `DATABASE_URL` for connectivity.

2. State & Session Security:
   - Generate secure, short-lived JWT (JSON Web Tokens) or secure HTTP-only cookies upon successful login.
   - Implement a FastAPI dependency (e.g., `get_current_user`) to protect API routes.

3. Configuration Security:
   - All external keys must be consumed via environment variables. Do NOT hardcode credentials. Expect the following variables to be injected via Cloud Run: `DATABASE_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `JWT_SECRET`.

4. Dynamic Port Mapping:
   - Ensure the app explicitly binds to the `PORT` environment variable provided by Cloud Run (defaulting to 8080 if absent), running via Uvicorn on host `0.0.0.0`.

### Frontend Requirements
Create a single-page HTML frontend (served statically via FastAPI's `StaticFiles` or inline templates) to act as the interface for my students.
- Style it beautifully using modern, clean CDN-delivered CSS (like Tailwind CSS or Pico.css).
- It must contain a distinct, polished authentication card with:
  - A prominent, styled "Sign in with Google" button.
  - A split divider ("or").
  - Form fields for a traditional Username/Password registration and login.
- Provide clean UI states: Display an interactive, protected "Dashboard" area showing the logged-in user's profile details once authenticated, along with a "Logout" button.

Please generate the required Python code files, `requirements.txt`, database migration/initialization scripts, and front-end code assets necessary to achieve this minimal, production-grade template.
