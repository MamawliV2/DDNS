import { Link } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from '../components/Navbar';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Card, CardContent } from '../components/ui/card';
import { Zap, Shield, Gift, LayoutDashboard, Layers, Server, Check, ArrowRight, Send } from 'lucide-react';

const TELEGRAM_URL = "https://t.me/DZ_CT";

const featureIcons = {
  speed: Zap,
  security: Shield,
  free: Gift,
  easy: LayoutDashboard,
  types: Layers,
  api: Server,
};

function FeatureCard({ iconKey, title, desc, className = "" }) {
  const Icon = featureIcons[iconKey];
  return (
    <Card className={`group border border-border/60 bg-card/50 backdrop-blur-sm hover:border-primary/30 transition-all duration-300 hover:-translate-y-0.5 ${className}`}>
      <CardContent className="p-6">
        <div className="w-10 h-10 rounded-md bg-primary/10 flex items-center justify-center mb-4 group-hover:bg-primary/20 transition-colors">
          <Icon className="h-5 w-5 text-primary" />
        </div>
        <h3 className="text-base font-semibold mb-2">{title}</h3>
        <p className="text-sm text-muted-foreground leading-relaxed">{desc}</p>
      </CardContent>
    </Card>
  );
}

function PricingCard({ plan, t, isPopular }) {
  const planData = t(`pricing.${plan}`);
  if (typeof planData !== 'object') return null;

  const isContact = plan === 'pro' || plan === 'enterprise';
  const href = isContact ? TELEGRAM_URL : '/register';

  return (
    <Card
      data-testid={`pricing-card-${plan}`}
      className={`relative border bg-card/50 backdrop-blur-sm transition-all duration-300 hover:-translate-y-1 ${
        isPopular ? 'border-primary shadow-lg shadow-primary/10' : 'border-border/60'
      }`}
    >
      {isPopular && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2">
          <Badge className="bg-primary text-primary-foreground px-3">Popular</Badge>
        </div>
      )}
      <CardContent className="p-8">
        <h3 className="text-lg font-semibold mb-2">{planData.title}</h3>
        <div className="mb-6">
          <span className="text-3xl font-bold">{planData.price}</span>
          {planData.period && (
            <span className="text-sm text-muted-foreground ms-1">/{planData.period}</span>
          )}
        </div>
        <ul className="space-y-3 mb-8">
          {planData.features?.map((feature, i) => (
            <li key={i} className="flex items-center gap-2 text-sm">
              <Check className="h-4 w-4 text-primary shrink-0" />
              <span>{feature}</span>
            </li>
          ))}
        </ul>
        {isContact ? (
          <a href={href} target="_blank" rel="noopener noreferrer" className="block">
            <Button
              variant={isPopular ? "default" : "outline"}
              className="w-full gap-2"
              data-testid={`pricing-cta-${plan}`}
            >
              <Send className="h-4 w-4" />
              {planData.cta}
            </Button>
          </a>
        ) : (
          <Link to={href}>
            <Button
              variant={isPopular ? "default" : "outline"}
              className="w-full gap-2"
              data-testid={`pricing-cta-${plan}`}
            >
              {planData.cta}
              <ArrowRight className="h-4 w-4" />
            </Button>
          </Link>
        )}
      </CardContent>
    </Card>
  );
}

export default function Landing() {
  const { t, lang } = useLanguage();
  const { user } = useAuth();

  return (
    <div className="min-h-screen bg-background" data-testid="landing-page">
      <Navbar />

      {/* Hero Section */}
      <section className="relative pt-32 pb-20 sm:pt-40 sm:pb-28 grid-bg overflow-hidden">
        <div className="absolute inset-0 opacity-[0.03]" style={{
          backgroundImage: `url("https://images.unsplash.com/photo-1664526936810-ec0856d31b92?crop=entropy&cs=srgb&fm=jpg&q=85")`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
        }} />
        <div className="relative max-w-4xl mx-auto px-4 sm:px-6 text-center">
          <div className="animate-fade-in-up">
            <Badge variant="secondary" className="mb-6 px-4 py-1.5 text-xs font-medium">
              Powered by Cloudflare
            </Badge>
          </div>
          <h1
            className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight mb-6 animate-fade-in-up delay-100"
            data-testid="hero-title"
          >
            {t('hero.title')}
          </h1>
          <p className="text-base sm:text-lg text-muted-foreground max-w-2xl mx-auto mb-10 leading-relaxed animate-fade-in-up delay-200">
            {t('hero.subtitle')}
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 animate-fade-in-up delay-300">
            <Link to={user ? "/dashboard" : "/register"}>
              <Button size="lg" className="gap-2 px-8" data-testid="hero-cta">
                {t('hero.cta')}
                <ArrowRight className="h-4 w-4" />
              </Button>
            </Link>
            <a href="#pricing">
              <Button variant="outline" size="lg" className="gap-2 px-8" data-testid="hero-pricing-btn">
                {t('hero.learn')}
              </Button>
            </a>
          </div>

          {/* Terminal preview */}
          <div className="mt-16 max-w-lg mx-auto animate-fade-in-up delay-400">
            <div className="rounded-lg border border-border/60 bg-card/80 backdrop-blur-sm overflow-hidden shadow-2xl shadow-black/10">
              <div className="flex items-center gap-1.5 px-4 py-2.5 bg-muted/50 border-b border-border/40">
                <div className="w-2.5 h-2.5 rounded-full bg-red-400/70" />
                <div className="w-2.5 h-2.5 rounded-full bg-yellow-400/70" />
                <div className="w-2.5 h-2.5 rounded-full bg-green-400/70" />
                <span className="ms-2 text-[10px] text-muted-foreground font-mono">terminal</span>
              </div>
              <div className={`p-4 font-mono text-xs sm:text-sm space-y-1.5 ${lang === 'fa' ? 'text-left' : ''}`} dir="ltr">
                <p className="text-muted-foreground">$ dig blog.dnslab.biz</p>
                <p><span className="text-green-400">;</span> ANSWER SECTION:</p>
                <p><span className="text-primary">blog.dnslab.biz.</span>  300  IN  A  <span className="text-accent">192.168.1.100</span></p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 sm:py-28" id="features">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="text-center mb-16">
            <h2 className="text-2xl sm:text-3xl font-bold mb-3" data-testid="features-title">
              {t('features.title')}
            </h2>
            <p className="text-muted-foreground">{t('features.subtitle')}</p>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {['speed', 'security', 'free', 'easy', 'types', 'api'].map((key) => (
              <FeatureCard
                key={key}
                iconKey={key}
                title={t(`features.${key}.title`)}
                desc={t(`features.${key}.desc`)}
              />
            ))}
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section className="py-20 sm:py-28 bg-muted/30" id="pricing">
        <div className="max-w-5xl mx-auto px-4 sm:px-6">
          <div className="text-center mb-16">
            <h2 className="text-2xl sm:text-3xl font-bold mb-3" data-testid="pricing-title">
              {t('pricing.title')}
            </h2>
            <p className="text-muted-foreground">{t('pricing.subtitle')}</p>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <PricingCard plan="free" t={t} />
            <PricingCard plan="pro" t={t} isPopular />
            <PricingCard plan="enterprise" t={t} />
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border/40 py-12">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
            <div className="text-center sm:text-start">
              <div className="flex items-center gap-2 justify-center sm:justify-start mb-2">
                <img src="/logo.svg" alt="" className="w-6 h-6 rounded" />
                <span className="font-bold" style={{ fontFamily: "'Syne', system-ui" }}>
                  DDNS<span className="text-primary">.LAND</span>
                </span>
              </div>
              <p className="text-xs text-muted-foreground">{t('footer.description')}</p>
            </div>
            <div className="flex items-center gap-6">
              <a
                href={TELEGRAM_URL}
                target="_blank"
                rel="noopener noreferrer"
                data-testid="footer-telegram"
                className="text-sm text-muted-foreground hover:text-foreground transition-colors flex items-center gap-1.5"
              >
                <Send className="h-3.5 w-3.5" />
                {t('footer.telegram')}
              </a>
            </div>
          </div>
          <div className="mt-8 pt-6 border-t border-border/40 text-center">
            <p className="text-xs text-muted-foreground">
              &copy; {new Date().getFullYear()} {t('footer.domain')}. {t('footer.rights')}
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
