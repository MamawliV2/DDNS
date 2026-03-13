<div dir="rtl">

# DNSLAB.BIZ - سرویس رایگان DNS داینامیک

> **[English](README.md)**

<div align="center">
  <img src="frontend/public/logo.svg" alt="DNSLAB.BIZ Logo" width="120" />

**پلتفرم مدیریت DNS داینامیک رایگان**

ساخت رایگان ساب دامین DNS روی **dnslab.biz** با زیرساخت واقعی Cloudflare

![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)
![React](https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=black)
![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=flat&logo=mongodb&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=flat&logo=cloudflare&logoColor=white)
![TailwindCSS](https://img.shields.io/badge/Tailwind-06B6D4?style=flat&logo=tailwindcss&logoColor=white)

</div>

---

## امکانات

- رکوردهای DNS رایگان - ساخت تا 2 رکورد A, AAAA, CNAME یا NS به صورت رایگان
- پشتیبانی چند دامنه - ادمین میتونه چندین دامنه اضافه کنه و کاربران دامنه مورد نظر رو انتخاب کنن
- DNS واقعی Cloudflare - رکوردها روی زیرساخت جهانی Cloudflare ساخته میشن
- تایید ایمیل - ارسال کد تایید 6 رقمی به Gmail قبل از فعال سازی حساب
- داشبورد کاربر - داشبورد مدرن و تمیز برای مدیریت رکوردهای DNS
- پنل مدیریت - مدیریت کاربران و دامنه ها و آمار پلتفرم
- دو زبانه - پشتیبانی کامل از فارسی و انگلیسی
- حالت تاریک و روشن - تغییر بین تم تاریک و روشن
- واکنش گرا - طراحی کاملا واکنش گرا برای موبایل
- فقط Gmail - ثبت نام فقط با آدرس های gmail.com
- پلن های ویژه - ارتقا به رکوردهای نامحدود از طریق تلگرام
- انیمیشن صفحات - انتقال نرم بین صفحات
- آیکون و رنگ متمایز - هر نوع رکورد DNS (A, AAAA, CNAME, NS) آیکون و رنگ مخصوص خودش رو داره
- کپی با یک کلیک - کپی نام کامل ساب دامین با یک کلیک
- اعلان تلگرام ادمین - هنگام ثبت نام کاربر جدید به ادمین در تلگرام اطلاع داده میشه
- دستور مدیریت ddns - مدیریت آسان پروژه بعد از نصب از طریق ترمینال

## فناوری ها

<div dir="ltr">

| Component | Technology |
|-----------|-----------|
| Frontend | React 18, Tailwind CSS, Shadcn/UI |
| Backend | Python FastAPI |
| Database | MongoDB |
| DNS | Cloudflare API |
| Auth | JWT (JSON Web Tokens) |

</div>

## شروع سریع

### نصب خودکار

<div dir="ltr">

```bash
git clone https://github.com/MamawliV2/DDNS.git
cd DDNS
chmod +x install.sh
./install.sh
```

</div>

اسکریپت نصب این کارها رو انجام میده:

1. بررسی و نصب تمام پیش نیازها (Python 3, Node.js, MongoDB, nginx, certbot)
2. پیکربندی دامنه و SSL با Let's Encrypt
3. دریافت API Token و Zone ID کلادفلر
4. دریافت اطلاعات تایید ایمیل (Gmail و App Password)
5. تنظیم تلگرام (بکاپ و اعلان ادمین) - اختیاری
6. پیکربندی دیتابیس
7. دریافت ایمیل و رمز ادمین
8. نصب وابستگی ها
9. تنظیم متغیرهای محیطی
10. بیلد فرانت اند
11. راه اندازی سرویس systemd
12. پیکربندی nginx در صورت استفاده از دامنه
13. دریافت گواهی SSL در صورت استفاده از دامنه
14. ساخت و ارتقای حساب ادمین
15. ثبت دستور مدیریت `ddns`
16. نمایش آدرس های دسترسی

### منوی مدیریت

بعد از نصب هر زمان نیاز به تغییرات داشتید:

<div dir="ltr">

```bash
ddns
```

```
  DNSLAB.BIZ - Management Panel

   1)  Update          (git pull + rebuild + restart)
   2)  Domain & SSL    (change domain, get SSL cert)
   3)  Environment     (edit backend/.env variables)
   4)  Cloudflare      (API token, zone ID)
   5)  Email / SMTP    (Gmail, app password)
   6)  Telegram        (bot token, chat ID, test)
   7)  Admin Account   (change admin email)
   8)  Restart Services(backend + nginx)
   9)  Status & Logs   (health check, logs)
  10)  Backup / Restore(database backup)

  11)  Apply All Changes & Restart
   0)  Exit
```

</div>

هر بخش بعد از تغییرات ازتون میپرسه میخاید همین الان اعمال بشه یا بعدا با گزینه 11 همه رو یکجا اعمال کنید.

### نصب دستی

#### پیش نیازها

- Python 3.8 به بالا
- Node.js 16 به بالا و Yarn
- MongoDB 4.4 به بالا
- حساب Cloudflare با یک دامنه

#### 1. کلون ریپوزیتوری

<div dir="ltr">

```bash
git clone https://github.com/MamawliV2/DDNS.git
cd DDNS
```

</div>

#### 2. راه اندازی بک اند

<div dir="ltr">

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

</div>

فایل `backend/.env` بسازید:

<div dir="ltr">

```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=ddns_land
CORS_ORIGINS=*
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
CLOUDFLARE_ZONE_ID=your_cloudflare_zone_id
JWT_SECRET=your_random_jwt_secret
ADMIN_EMAIL=your_admin@gmail.com
SMTP_EMAIL=your_gmail@gmail.com
SMTP_PASSWORD=your_16_char_app_password
```

</div>

اجرای بک اند:

<div dir="ltr">

```bash
uvicorn server:app --host 0.0.0.0 --port 8001 --reload
```

</div>

#### 3. راه اندازی فرانت اند

<div dir="ltr">

```bash
cd frontend
yarn install
```

</div>

فایل `frontend/.env` بسازید:

<div dir="ltr">

```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

</div>

اجرای فرانت اند:

<div dir="ltr">

```bash
yarn start
```

</div>

#### 4. راه اندازی حساب ادمین

با ایمیلی که در ADMIN_EMAIL تنظیم کردید ثبت نام کنید و بعد این دستور رو بزنید:

<div dir="ltr">

```bash
curl -X POST http://localhost:8001/api/admin/setup
```

</div>

## دریافت اطلاعات Cloudflare

### API Token

1. وارد [داشبورد Cloudflare](https://dash.cloudflare.com) بشید
2. آیکون پروفایل و بعد My Profile
3. API Tokens و بعد Create Token
4. قالب Edit zone DNS رو انتخاب کنید
5. در Zone Resources دامنه خودتون رو انتخاب کنید
6. Continue to summary و بعد Create Token
7. توکن رو کپی کنید - فقط یک بار نمایش داده میشه

### Zone ID

1. وارد [داشبورد Cloudflare](https://dash.cloudflare.com) بشید
2. روی دامنه خودتون کلیک کنید
3. در صفحه Overview در ستون سمت راست Zone ID رو پیدا کنید
4. Zone ID رو کپی کنید

## راه اندازی تایید ایمیل

تایید ایمیل نیاز به یک حساب Gmail با App Password داره. این برای ارسال کد تایید 6 رقمی به کاربران هنگام ثبت نام استفاده میشه.

### مرحله 1 - فعال سازی تایید دو مرحله ای

1. وارد [تنظیمات امنیتی گوگل](https://myaccount.google.com/security) بشید
2. گزینه 2-Step Verification رو پیدا و فعال کنید
3. مراحل رو دنبال کنید

### مرحله 2 - ساخت App Password

1. وارد [App Passwords گوگل](https://myaccount.google.com/apppasswords) بشید
2. یک نام وارد کنید مثلا DNSLAB
3. روی Create کلیک کنید
4. گوگل یک رمز 16 کاراکتری نشون میده مثلا `abcd efgh ijkl mnop`
5. این رمز رو کپی کنید - برای نصب بهش نیاز دارید

### مرحله 3 - پیکربندی

اگه از اسکریپت نصب خودکار استفاده میکنید خودش میپرسه. اگه دستی نصب میکنید به `backend/.env` اضافه کنید:

<div dir="ltr">

```env
SMTP_EMAIL=your_gmail@gmail.com
SMTP_PASSWORD=abcd efgh ijkl mnop
```

</div>

### نحوه کارکرد

1. کاربر با آدرس Gmail ثبت نام میکنه
2. یک کد تایید 6 رقمی به ایمیلش ارسال میشه
3. کاربر کد رو در صفحه تایید وارد میکنه
4. بعد از تایید میتونه وارد بشه و از داشبورد استفاده کنه
5. کدهای تایید بعد از 10 دقیقه منقضی میشن
6. کاربر میتونه کد جدید درخواست کنه

## اندپوینت های API

### احراز هویت

<div dir="ltr">

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | ثبت نام - ارسال کد تایید |
| POST | `/api/auth/verify` | تایید ایمیل با کد 6 رقمی |
| POST | `/api/auth/resend-code` | ارسال مجدد کد تایید |
| POST | `/api/auth/login` | ورود - فقط کاربران تایید شده |
| GET | `/api/auth/me` | اطلاعات کاربر فعلی |

</div>

### رکوردهای DNS

<div dir="ltr">

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dns/records` | لیست رکوردهای کاربر |
| POST | `/api/dns/records` | ساخت رکورد DNS |
| PUT | `/api/dns/records/:id` | ویرایش رکورد |
| DELETE | `/api/dns/records/:id` | حذف رکورد |
| GET | `/api/domains` | لیست دامنه های فعال |

</div>

### مدیریت

<div dir="ltr">

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/stats` | آمار پلتفرم |
| GET | `/api/admin/users` | لیست کاربران |
| PUT | `/api/admin/users/:id/plan` | تغییر پلن کاربر |
| DELETE | `/api/admin/users/:id` | حذف کاربر |
| GET | `/api/admin/domains` | لیست دامنه ها |
| POST | `/api/admin/domains` | افزودن دامنه |
| PUT | `/api/admin/domains/:id` | ویرایش دامنه |
| DELETE | `/api/admin/domains/:id` | حذف دامنه |
| POST | `/api/admin/setup` | ارتقای کاربر به ادمین |

</div>

## ساختار پروژه

<div dir="ltr">

```
dnslab-biz/
├── backend/
│   ├── server.py           # FastAPI application
│   ├── requirements.txt    # Python dependencies
│   └── .env               # Backend environment variables
├── frontend/
│   ├── public/
│   │   ├── index.html
│   │   ├── logo.svg
│   │   └── favicon.svg
│   ├── src/
│   │   ├── components/
│   │   │   ├── ui/         # Shadcn UI components
│   │   │   └── Navbar.js
│   │   ├── contexts/
│   │   │   ├── AuthContext.js
│   │   │   ├── ThemeContext.js
│   │   │   └── LanguageContext.js
│   │   ├── pages/
│   │   │   ├── Landing.js
│   │   │   ├── Login.js
│   │   │   ├── Register.js
│   │   │   ├── VerifyEmail.js
│   │   │   ├── Dashboard.js
│   │   │   └── Admin.js
│   │   ├── translations/
│   │   │   └── index.js
│   │   ├── App.js
│   │   └── index.css
│   ├── package.json
│   └── .env
├── install.sh
├── backup.sh
└── README.md
```

</div>

## پلن ها و محدودیت ها

<div dir="ltr">

| Feature | Free | Premium |
|---------|------|---------|
| DNS Records | 2 | Unlimited |
| Record Types | A, AAAA, CNAME, NS | A, AAAA, CNAME, NS |
| Cloudflare DNS | Yes | Yes |
| Dashboard | Yes | Yes |
| Priority Support | No | Yes |

</div>

## متغیرهای محیطی

### بک اند - backend/.env

<div dir="ltr">

| Variable | Description | Required |
|----------|-------------|----------|
| `MONGO_URL` | MongoDB connection string | Yes |
| `DB_NAME` | Database name | Yes |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token | Yes |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID | Yes |
| `JWT_SECRET` | JWT signing secret | Yes |
| `ADMIN_EMAIL` | Admin user email | Yes |
| `SMTP_EMAIL` | Gmail for verification emails | Yes |
| `SMTP_PASSWORD` | Gmail App Password (16 chars) | Yes |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token (backups & alerts) | No |
| `TELEGRAM_CHAT_ID` | Telegram chat ID (backups & alerts) | No |
| `CORS_ORIGINS` | Allowed CORS origins | No |

</div>

### فرانت اند - frontend/.env

<div dir="ltr">

| Variable | Description | Required |
|----------|-------------|----------|
| `REACT_APP_BACKEND_URL` | Backend API URL | Yes |

</div>

## بکاپ و بازگردانی

پروژه شامل یک سیستم بکاپ خودکار هست که دیتابیس MongoDB رو ذخیره و به حساب تلگرام شما ارسال میکنه. همچنین هنگام ثبت نام کاربر جدید به ادمین در تلگرام اطلاع داده میشه.

### پیش نیازها

1. ساخت بات تلگرام - به `@BotFather` پیام بدید و `/newbot` بفرستید و توکن بات رو کپی کنید
2. دریافت Chat ID - به `@userinfobot` پیام بدید و Chat ID رو کپی کنید
3. بات رو Start کنید - الزامی
4. به فایل env اضافه کنید:

<div dir="ltr">

```bash
echo 'TELEGRAM_BOT_TOKEN=your_bot_token' >> backend/.env
echo 'TELEGRAM_CHAT_ID=your_chat_id' >> backend/.env
```

</div>

### بکاپ دستی

<div dir="ltr">

```bash
cd ~/DDNS
bash backup.sh backup
```

</div>

در تلگرام فایلی با این جزئیات دریافت میکنید:

```
DNSLAB Backup
Date: 2026-03-09 03:00
Size: 12K
Users: 25
Records: 48
Domains: 3
```

### بکاپ خودکار روزانه

تنظیم برای بکاپ روزانه ساعت 3 صبح:

<div dir="ltr">

```bash
bash backup.sh cron
```

</div>

### بازگردانی از بکاپ

روی همون سرور:

<div dir="ltr">

```bash
bash backup.sh restore
```

</div>

سپس شماره بکاپ رو انتخاب کنید و با y تایید کنید و بعد ریستارت کنید:

<div dir="ltr">

```bash
sudo systemctl restart ddns-backend
```

</div>

### انتقال به سرور جدید

<div dir="ltr">

```bash
# 1. Install on new server
git clone https://github.com/MamawliV2/DDNS.git
cd DDNS
sudo bash install.sh

# 2. Copy backup file from Telegram to server
mkdir -p backups
scp user@pc:~/Downloads/backup.tar.gz ~/DDNS/backups/

# 3. Restore
bash backup.sh restore

# 4. Restart
sudo systemctl restart ddns-backend
```

</div>

### تمام دستورات بکاپ

<div dir="ltr">

| Command | Description |
|---------|-------------|
| `bash backup.sh backup` | Backup + send to Telegram |
| `bash backup.sh restore` | Restore from backups |
| `bash backup.sh restore file.tar.gz` | Restore specific file |
| `bash backup.sh cron` | Setup daily auto-backup |
| `bash backup.sh auto` | Silent backup (for cron) |

</div>

## نکات امنیتی

- هرگز فایل های env رو در گیتهاب commit نکنید
- از مقادیر قوی و یکتا برای JWT_SECRET استفاده کنید
- توکن های API کلادفلر باید حداقل دسترسی رو داشته باشن
- گواهی های SSL توسط certbot خودکار تمدید میشن

## مشارکت

1. ریپوزیتوری رو Fork کنید
2. یک شاخه جدید بسازید
3. تغییرات رو Commit کنید
4. Pull Request باز کنید

## لایسنس

این پروژه متن باز هست و تحت [لایسنس MIT](LICENSE) در دسترسه.

## تماس

برای پلن های ویژه یا پشتیبانی از طریق تلگرام تماس بگیرید: [@DZ_CT](https://t.me/DZ_CT)

</div>
