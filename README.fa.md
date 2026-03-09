# DNSLAB.BIZ - سرویس رایگان DNS داینامیک

> **[English](README.md)**

<div align="center">
  <img src="frontend/public/logo.svg" alt="DNSLAB.BIZ Logo" width="120" />
  <h3>پلتفرم مدیریت DNS داینامیک رایگان</h3>
  <p>ساخت رایگان ساب‌دامین DNS روی <strong>dnslab.biz</strong> با زیرساخت واقعی Cloudflare</p>
  
  ![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)
  ![React](https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=black)
  ![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=flat&logo=mongodb&logoColor=white)
  ![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=flat&logo=cloudflare&logoColor=white)
  ![TailwindCSS](https://img.shields.io/badge/Tailwind-06B6D4?style=flat&logo=tailwindcss&logoColor=white)
</div>

---

## امکانات

- **رکوردهای DNS رایگان** - ساخت تا ۲ رکورد A، AAAA، CNAME یا NS به صورت رایگان
- **پشتیبانی چند دامنه** - ادمین می‌تونه چندین دامنه اضافه کنه و کاربران دامنه مورد نظر رو انتخاب کنن
- **DNS واقعی Cloudflare** - رکوردها روی زیرساخت جهانی Cloudflare ساخته می‌شن
- **تایید ایمیل** - ارسال کد تایید ۶ رقمی به Gmail قبل از فعال‌سازی حساب
- **داشبورد کاربر** - داشبورد مدرن و تمیز برای مدیریت رکوردهای DNS
- **پنل مدیریت** - مدیریت کاربران، مدیریت دامنه‌ها و آمار پلتفرم
- **دو زبانه** - پشتیبانی کامل از فارسی (RTL) و انگلیسی
- **حالت تاریک/روشن** - تغییر بین تم تاریک و روشن
- **واکنش‌گرا** - طراحی کاملاً واکنش‌گرا برای موبایل
- **فقط Gmail** - ثبت‌نام فقط با آدرس‌های @gmail.com
- **پلن‌های ویژه** - ارتقا به رکوردهای نامحدود از طریق تلگرام

## فناوری‌ها

| بخش | فناوری |
|-----|--------|
| فرانت‌اند | React 18, Tailwind CSS, Shadcn/UI |
| بک‌اند | Python FastAPI |
| دیتابیس | MongoDB |
| DNS | Cloudflare API |
| احراز هویت | JWT (JSON Web Tokens) |

## شروع سریع

### نصب خودکار

```bash
git clone https://github.com/MamawliV2/DDNS.git
cd DDNS
chmod +x install.sh
./install.sh
```

اسکریپت نصب:
1. بررسی و نصب تمام پیش‌نیازها (Python 3, Node.js, MongoDB, nginx, certbot)
2. پیکربندی دامنه و SSL (با Let's Encrypt)
3. دریافت API Token و Zone ID کلادفلر
4. دریافت اطلاعات تایید ایمیل (Gmail + App Password)
5. پیکربندی دیتابیس
6. دریافت ایمیل و رمز ادمین
7. نصب وابستگی‌ها
8. تنظیم متغیرهای محیطی
9. بیلد فرانت‌اند
10. راه‌اندازی سرویس systemd
11. پیکربندی nginx (در صورت استفاده از دامنه)
12. دریافت گواهی SSL (در صورت استفاده از دامنه)
13. ساخت و ارتقای حساب ادمین
14. نمایش آدرس‌های دسترسی

### نصب دستی

#### پیش‌نیازها

- Python 3.8+
- Node.js 16+ و Yarn
- MongoDB 4.4+
- حساب Cloudflare با یک دامنه

#### ۱. کلون ریپوزیتوری

```bash
git clone https://github.com/MamawliV2/DDNS.git
cd DDNS
```

#### ۲. راه‌اندازی بک‌اند

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

فایل `backend/.env` بسازید:
```env
MONGO_URL=mongodb://localhost:27017
DB_NAME=ddns_land
CORS_ORIGINS=*
CLOUDFLARE_API_TOKEN=توکن_API_کلادفلر
CLOUDFLARE_ZONE_ID=شناسه_زون_کلادفلر
JWT_SECRET=یک_رشته_تصادفی
ADMIN_EMAIL=ایمیل_ادمین@gmail.com
SMTP_EMAIL=ایمیل_جیمیل@gmail.com
SMTP_PASSWORD=رمز_۱۶_کاراکتری_اپلیکیشن
```

اجرای بک‌اند:
```bash
uvicorn server:app --host 0.0.0.0 --port 8001 --reload
```

#### ۳. راه‌اندازی فرانت‌اند

```bash
cd frontend
yarn install
```

فایل `frontend/.env` بسازید:
```env
REACT_APP_BACKEND_URL=http://localhost:8001
```

اجرای فرانت‌اند:
```bash
yarn start
```

#### ۴. راه‌اندازی حساب ادمین

1. با ایمیلی که در `ADMIN_EMAIL` تنظیم کردید ثبت‌نام کنید
2. اندپوینت تنظیم ادمین رو صدا بزنید:
```bash
curl -X POST http://localhost:8001/api/admin/setup
```

## دریافت اطلاعات Cloudflare

### API Token

1. وارد [داشبورد Cloudflare](https://dash.cloudflare.com) بشید
2. آیکون پروفایل → **My Profile**
3. **API Tokens** → **Create Token**
4. قالب **Edit zone DNS** رو انتخاب کنید
5. در Zone Resources دامنه خودتون رو انتخاب کنید
6. **Continue to summary** → **Create Token**
7. توکن رو کپی کنید (فقط یک بار نمایش داده می‌شه!)

### Zone ID

1. وارد [داشبورد Cloudflare](https://dash.cloudflare.com) بشید
2. روی دامنه خودتون کلیک کنید
3. در صفحه Overview، **Zone ID** رو در ستون سمت راست پیدا کنید
4. Zone ID رو کپی کنید

## راه‌اندازی تایید ایمیل

تایید ایمیل نیاز به یک حساب Gmail با **App Password** داره. این برای ارسال کد تایید ۶ رقمی به کاربران هنگام ثبت‌نام استفاده می‌شه.

### مرحله ۱: فعال‌سازی تایید دو مرحله‌ای

1. وارد [تنظیمات امنیتی گوگل](https://myaccount.google.com/security) بشید
2. **2-Step Verification** رو پیدا و فعال کنید
3. مراحل رو دنبال کنید

### مرحله ۲: ساخت App Password

1. وارد [App Passwords گوگل](https://myaccount.google.com/apppasswords) بشید
2. یک نام وارد کنید (مثلاً `DNSLAB`)
3. روی **Create** کلیک کنید
4. گوگل یک **رمز ۱۶ کاراکتری** نشون میده (مثلاً `abcd efgh ijkl mnop`)
5. **این رمز رو کپی کنید** - برای نصب بهش نیاز دارید

### مرحله ۳: پیکربندی

اگه از اسکریپت نصب خودکار استفاده می‌کنید، خودش می‌پرسه:
- **آدرس Gmail**: جیمیلی که App Password رو باهاش ساختید
- **App Password**: کد ۱۶ کاراکتری از مرحله ۲

اگه دستی نصب می‌کنید، به `backend/.env` اضافه کنید:
```env
SMTP_EMAIL=ایمیل_جیمیل@gmail.com
SMTP_PASSWORD=abcd efgh ijkl mnop
```

### نحوه کارکرد

1. کاربر با آدرس Gmail ثبت‌نام می‌کنه
2. یک کد تایید ۶ رقمی به ایمیلش ارسال می‌شه
3. کاربر کد رو در صفحه تایید وارد می‌کنه
4. بعد از تایید می‌تونه وارد بشه و از داشبورد استفاده کنه
5. کدهای تایید بعد از ۱۰ دقیقه منقضی می‌شن
6. کاربر می‌تونه کد جدید درخواست کنه

## اندپوینت‌های API

### احراز هویت
| متد | اندپوینت | توضیح |
|-----|----------|-------|
| POST | `/api/auth/register` | ثبت‌نام (فقط Gmail) - ارسال کد تایید |
| POST | `/api/auth/verify` | تایید ایمیل با کد ۶ رقمی |
| POST | `/api/auth/resend-code` | ارسال مجدد کد تایید |
| POST | `/api/auth/login` | ورود (فقط کاربران تایید شده) |
| GET | `/api/auth/me` | اطلاعات کاربر فعلی |

### رکوردهای DNS
| متد | اندپوینت | توضیح |
|-----|----------|-------|
| GET | `/api/dns/records` | لیست رکوردهای کاربر |
| POST | `/api/dns/records` | ساخت رکورد DNS |
| PUT | `/api/dns/records/:id` | ویرایش رکورد |
| DELETE | `/api/dns/records/:id` | حذف رکورد |
| GET | `/api/domains` | لیست دامنه‌های فعال |

### مدیریت
| متد | اندپوینت | توضیح |
|-----|----------|-------|
| GET | `/api/admin/stats` | آمار پلتفرم |
| GET | `/api/admin/users` | لیست کاربران |
| PUT | `/api/admin/users/:id/plan` | تغییر پلن کاربر |
| DELETE | `/api/admin/users/:id` | حذف کاربر |
| GET | `/api/admin/domains` | لیست دامنه‌ها |
| POST | `/api/admin/domains` | افزودن دامنه |
| PUT | `/api/admin/domains/:id` | ویرایش دامنه (فعال/غیرفعال) |
| DELETE | `/api/admin/domains/:id` | حذف دامنه |
| POST | `/api/admin/setup` | ارتقای کاربر به ادمین |

## ساختار پروژه

```
dnslab-biz/
├── backend/
│   ├── server.py           # اپلیکیشن FastAPI
│   ├── requirements.txt    # وابستگی‌های پایتون
│   └── .env               # متغیرهای محیطی بک‌اند
├── frontend/
│   ├── public/
│   │   ├── index.html      # قالب HTML
│   │   ├── logo.svg        # لوگوی اپلیکیشن
│   │   └── favicon.svg     # فاویکون مرورگر
│   ├── src/
│   │   ├── components/
│   │   │   ├── ui/         # کامپوننت‌های Shadcn UI
│   │   │   └── Navbar.js   # نوار ناوبری
│   │   ├── contexts/
│   │   │   ├── AuthContext.js      # وضعیت احراز هویت
│   │   │   ├── ThemeContext.js     # تم تاریک/روشن
│   │   │   └── LanguageContext.js  # زبان EN/FA
│   │   ├── pages/
│   │   │   ├── Landing.js   # صفحه اصلی
│   │   │   ├── Login.js     # صفحه ورود
│   │   │   ├── Register.js  # صفحه ثبت‌نام
│   │   │   ├── VerifyEmail.js # صفحه تایید ایمیل
│   │   │   ├── Dashboard.js # مدیریت DNS
│   │   │   └── Admin.js     # پنل مدیریت
│   │   ├── translations/
│   │   │   └── index.js     # ترجمه‌های EN/FA
│   │   ├── App.js           # کامپوننت اصلی
│   │   └── index.css        # استایل‌های سراسری
│   ├── package.json
│   └── .env               # متغیرهای محیطی فرانت‌اند
├── install.sh              # اسکریپت نصب خودکار
├── backup.sh               # اسکریپت بکاپ و بازگردانی
└── README.md
```

## پلن‌ها و محدودیت‌ها

| امکان | رایگان | ویژه |
|-------|--------|------|
| رکوردهای DNS | ۲ | نامحدود |
| انواع رکورد | A, AAAA, CNAME, NS | A, AAAA, CNAME, NS |
| DNS Cloudflare | بله | بله |
| داشبورد | بله | بله |
| پشتیبانی اولویت‌دار | خیر | بله |
| TTL سفارشی | خیر | بله |

## متغیرهای محیطی

### بک‌اند (`backend/.env`)

| متغیر | توضیح | الزامی |
|--------|-------|--------|
| `MONGO_URL` | رشته اتصال MongoDB | بله |
| `DB_NAME` | نام دیتابیس | بله |
| `CLOUDFLARE_API_TOKEN` | توکن API کلادفلر | بله |
| `CLOUDFLARE_ZONE_ID` | شناسه زون کلادفلر | بله |
| `JWT_SECRET` | کلید امضای JWT | بله |
| `ADMIN_EMAIL` | ایمیل ادمین | بله |
| `SMTP_EMAIL` | آدرس Gmail برای ارسال ایمیل تایید | بله |
| `SMTP_PASSWORD` | App Password جیمیل (۱۶ کاراکتر) | بله |
| `TELEGRAM_BOT_TOKEN` | توکن بات تلگرام (برای بکاپ) | خیر |
| `TELEGRAM_CHAT_ID` | شناسه چت تلگرام (برای بکاپ) | خیر |
| `CORS_ORIGINS` | مبداهای مجاز CORS | خیر (پیش‌فرض: *) |

### فرانت‌اند (`frontend/.env`)

| متغیر | توضیح | الزامی |
|--------|-------|--------|
| `REACT_APP_BACKEND_URL` | آدرس API بک‌اند | بله |

## بکاپ و بازگردانی

پروژه شامل یک سیستم بکاپ خودکار هست که دیتابیس MongoDB رو ذخیره و به حساب تلگرام شما ارسال می‌کنه.

### پیش‌نیازها

1. **ساخت بات تلگرام:**
   - در تلگرام به `@BotFather` پیام بدید
   - `/newbot` بفرستید و مراحل رو دنبال کنید
   - **توکن بات** رو کپی کنید (مثلاً `123456:ABC-DEF...`)

2. **دریافت Chat ID:**
   - در تلگرام به `@userinfobot` پیام بدید
   - **Chat ID** رو کپی کنید (مثلاً `865122337`)

3. **استارت بات:**
   - بات خودتون رو در تلگرام باز کنید و **Start** رو بزنید (الزامی!)

4. **افزودن به محیط:**
   ```bash
   echo 'TELEGRAM_BOT_TOKEN=توکن_بات' >> backend/.env
   echo 'TELEGRAM_CHAT_ID=شناسه_چت' >> backend/.env
   ```

### بکاپ دستی

گرفتن بکاپ و ارسال به تلگرام:

```bash
cd ~/DDNS
bash backup.sh backup
```

خروجی:
```
  DNSLAB.BIZ - Database Backup

  [OK] Backup created: backups/ddns_land_2026-03-09_03-00-00.tar.gz (12K)
  [OK] Sent to Telegram
  [OK] Cleanup: keeping last 7 backups
  [OK] Backup complete!
```

در تلگرام فایلی با این جزئیات دریافت می‌کنید:
```
✅ DNSLAB Backup
📅 2026-03-09 03:00
📦 Size: 12K
👥 Users: 25
📋 Records: 48
🌐 Domains: 3
```

### بکاپ خودکار روزانه

تنظیم cron job برای بکاپ روزانه ساعت ۳ صبح:

```bash
bash backup.sh cron
```

### بازگردانی از بکاپ

**روی همون سرور (بازگردانی بکاپ قبلی):**

```bash
bash backup.sh restore
```

سپس:
1. لیست بکاپ‌های موجود نمایش داده می‌شه
2. شماره بکاپ رو انتخاب کنید
3. با `y` تایید کنید
4. ریستارت: `sudo systemctl restart ddns-backend`

**روی سرور جدید (انتقال):**

```bash
# ۱. نصب پروژه روی سرور جدید
git clone https://github.com/MamawliV2/DDNS.git
cd DDNS
sudo bash install.sh

# ۲. فایل بکاپ رو از تلگرام دانلود و به سرور منتقل کنید
mkdir -p backups
scp user@your-pc:~/Downloads/ddns_land_2026-03-09.tar.gz ~/DDNS/backups/

# ۳. بازگردانی
bash backup.sh restore

# ۴. ریستارت بک‌اند
sudo systemctl restart ddns-backend
```

### بازگردانی از فایل مشخص

```bash
bash backup.sh restore /path/to/backup_file.tar.gz
```

### تمام دستورات بکاپ

| دستور | توضیح |
|-------|-------|
| `bash backup.sh backup` | بکاپ الان + ارسال به تلگرام |
| `bash backup.sh restore` | بازگردانی از بکاپ‌های موجود |
| `bash backup.sh restore file.tar.gz` | بازگردانی از فایل مشخص |
| `bash backup.sh cron` | تنظیم بکاپ خودکار روزانه (ساعت ۳ صبح) |
| `bash backup.sh auto` | بکاپ بی‌صدا (برای cron) |

> **نکته:** بکاپ‌های محلی در پوشه `backups/` ذخیره می‌شن. فقط ۷ بکاپ آخر نگهداری می‌شن.

## نکات امنیتی

- هرگز فایل‌های `.env` رو در سیستم کنترل نسخه commit نکنید (`.gitignore` از قبل تنظیم شده)
- از مقادیر قوی و یکتا برای `JWT_SECRET` استفاده کنید (اسکریپت نصب خودکار تولید می‌کنه)
- توکن‌های API کلادفلر باید حداقل دسترسی رو داشته باشن (فقط Edit Zone DNS)
- اندپوینت `/api/admin/setup` بعد از تنظیم اولیه در محیط عملیاتی باید غیرفعال بشه
- گواهی‌های SSL توسط cron job مربوط به certbot خودکار تمدید می‌شن

## مشارکت

1. ریپوزیتوری رو Fork کنید
2. یک شاخه جدید بسازید (`git checkout -b feature/amazing-feature`)
3. تغییرات رو Commit کنید (`git commit -m 'Add amazing feature'`)
4. به شاخه Push کنید (`git push origin feature/amazing-feature`)
5. Pull Request باز کنید

## لایسنس

این پروژه متن‌باز هست و تحت [لایسنس MIT](LICENSE) در دسترسه.

## تماس

برای پلن‌های ویژه یا پشتیبانی، از طریق تلگرام تماس بگیرید: [@DZ_CT](https://t.me/DZ_CT)
