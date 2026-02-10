# DDNS.LAND - Free Dynamic DNS Service

<div align="center">
  <img src="frontend/public/logo.svg" alt="DDNS.LAND Logo" width="120" />
  <h3>Free Dynamic DNS Management Platform</h3>
  <p>Create free DNS subdomains on <strong>ddns.land</strong> with real Cloudflare infrastructure</p>
  
  ![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)
  ![React](https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=black)
  ![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=flat&logo=mongodb&logoColor=white)
  ![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=flat&logo=cloudflare&logoColor=white)
  ![TailwindCSS](https://img.shields.io/badge/Tailwind-06B6D4?style=flat&logo=tailwindcss&logoColor=white)
</div>

---

## Features

- **Free DNS Records** - Create up to 2 A, AAAA, or CNAME records for free
- **Real Cloudflare DNS** - Records are created on Cloudflare's global infrastructure
- **User Dashboard** - Clean, modern dashboard for managing all DNS records
- **Admin Panel** - Full user management, plan control, and platform statistics
- **Bilingual** - Full support for English and Persian (Farsi) with RTL layout
- **Dark/Light Mode** - Toggle between dark and light themes
- **Mobile Responsive** - Fully responsive design with mobile card views
- **Gmail-only Registration** - Registration restricted to @gmail.com addresses
- **Premium Plans** - Upgrade to unlimited records via Telegram contact

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Frontend  | React 18, Tailwind CSS, Shadcn/UI |
| Backend   | Python FastAPI |
| Database  | MongoDB |
| DNS       | Cloudflare API |
| Auth      | JWT (JSON Web Tokens) |

## Quick Start

### Automated Installation

```bash
chmod +x install.sh
./install.sh
```

The install script will:
1. Check and install all prerequisites (Python 3, Node.js, MongoDB, nginx, certbot)
2. Ask if you want to use a custom domain (+ SSL with Let's Encrypt)
3. Ask for your Cloudflare API Token and Zone ID
4. Ask for admin email and password
5. Install all dependencies
6. Configure environment variables
7. Build the frontend for production
8. Setup systemd service for backend
9. Configure nginx as reverse proxy (if using domain)
10. Obtain SSL certificate with certbot (if using domain)
11. Create and promote the admin account
12. Display access URLs including admin panel link

### Manual Installation

#### Prerequisites

- Python 3.8+
- Node.js 16+ & Yarn
- MongoDB 4.4+
- Cloudflare account with a domain

#### 1. Clone the repository

```bash
git clone https://github.com/yourusername/ddns-land.git
cd ddns-land
```

#### 2. Backend Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Create `backend/.env`:
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=ddns_land
CORS_ORIGINS=*
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
CLOUDFLARE_ZONE_ID=your_cloudflare_zone_id
JWT_SECRET=your_random_jwt_secret
ADMIN_EMAIL=your_admin@gmail.com
```

Start the backend:
```bash
uvicorn server:app --host 0.0.0.0 --port 8001 --reload
```

#### 3. Frontend Setup

```bash
cd frontend
yarn install
```

Create `frontend/.env`:
```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

Start the frontend:
```bash
yarn start
```

#### 4. Setup Admin Account

1. Register with the admin email you configured in `ADMIN_EMAIL`
2. Call the setup endpoint:
```bash
curl -X POST http://localhost:8001/api/admin/setup
```

## Getting Cloudflare Credentials

### API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click your profile icon → **My Profile**
3. Navigate to **API Tokens** → **Create Token**
4. Select **Edit zone DNS** template
5. Under Zone Resources, select your domain (`ddns.land`)
6. Click **Continue to summary** → **Create Token**
7. Copy the token (shown only once!)

### Zone ID

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click on your domain
3. On the Overview page, find **Zone ID** on the right sidebar
4. Copy the Zone ID

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register (Gmail only) |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Get current user info |

### DNS Records
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dns/records` | List user's records |
| POST | `/api/dns/records` | Create DNS record |
| PUT | `/api/dns/records/:id` | Update DNS record |
| DELETE | `/api/dns/records/:id` | Delete DNS record |

### Admin
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/stats` | Platform statistics |
| GET | `/api/admin/users` | List all users |
| PUT | `/api/admin/users/:id/plan` | Change user plan |
| DELETE | `/api/admin/users/:id` | Delete user |
| POST | `/api/admin/setup` | Promote admin user |

## Project Structure

```
ddns-land/
├── backend/
│   ├── server.py           # FastAPI application
│   ├── requirements.txt    # Python dependencies
│   └── .env               # Backend environment variables
├── frontend/
│   ├── public/
│   │   ├── index.html      # HTML template
│   │   ├── logo.svg        # Application logo
│   │   └── favicon.svg     # Browser favicon
│   ├── src/
│   │   ├── components/
│   │   │   ├── ui/         # Shadcn UI components
│   │   │   └── Navbar.js   # Navigation bar
│   │   ├── contexts/
│   │   │   ├── AuthContext.js      # Authentication state
│   │   │   ├── ThemeContext.js     # Dark/Light theme
│   │   │   └── LanguageContext.js  # EN/FA language
│   │   ├── pages/
│   │   │   ├── Landing.js   # Homepage
│   │   │   ├── Login.js     # Login page
│   │   │   ├── Register.js  # Registration page
│   │   │   ├── Dashboard.js # DNS management
│   │   │   └── Admin.js     # Admin panel
│   │   ├── translations/
│   │   │   └── index.js     # EN/FA translations
│   │   ├── App.js           # Root component
│   │   └── index.css        # Global styles
│   ├── package.json
│   └── .env               # Frontend environment variables
├── install.sh              # Automated install script
└── README.md
```

## Plans & Limits

| Feature | Free | Premium |
|---------|------|---------|
| DNS Records | 2 | Unlimited |
| Record Types | A, AAAA, CNAME | A, AAAA, CNAME |
| Cloudflare DNS | Yes | Yes |
| Dashboard | Yes | Yes |
| Priority Support | No | Yes |
| Custom TTL | No | Yes |

## Environment Variables

### Backend (`backend/.env`)

| Variable | Description | Required |
|----------|-------------|----------|
| `MONGO_URL` | MongoDB connection string | Yes |
| `DB_NAME` | Database name | Yes |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token | Yes |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID | Yes |
| `JWT_SECRET` | JWT signing secret | Yes |
| `ADMIN_EMAIL` | Admin user email | Yes |
| `CORS_ORIGINS` | Allowed CORS origins | No (default: *) |

### Frontend (`frontend/.env`)

| Variable | Description | Required |
|----------|-------------|----------|
| `REACT_APP_BACKEND_URL` | Backend API URL | Yes |

## Security Notes

- Never commit `.env` files to version control
- Use strong, unique `JWT_SECRET` values in production
- Cloudflare API tokens should have minimal permissions (Edit Zone DNS only)
- The admin setup endpoint (`/api/admin/setup`) should be disabled after initial setup in production

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source and available under the [MIT License](LICENSE).

## Contact

For premium plans or support, contact via Telegram: [@DZ_CT](https://t.me/DZ_CT)
