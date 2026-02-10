import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from '../components/Navbar';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { toast } from 'sonner';
import { LogIn, Loader2 } from 'lucide-react';

export default function Login() {
  const { t } = useLanguage();
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await login(email, password);
      toast.success('Welcome back!');
      navigate('/dashboard');
    } catch (err) {
      const msg = err.response?.data?.detail || 'Login failed. Please try again.';
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background grid-bg" data-testid="login-page">
      <Navbar />
      <div className="flex items-center justify-center min-h-screen px-4 pt-16">
        <Card className="w-full max-w-md border-border/60 bg-card/80 backdrop-blur-sm">
          <CardHeader className="text-center pb-2">
            <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mx-auto mb-4">
              <LogIn className="h-6 w-6 text-primary" />
            </div>
            <CardTitle className="text-xl">{t('auth.login_title')}</CardTitle>
            <CardDescription>{t('auth.login_subtitle')}</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email">{t('auth.email')}</Label>
                <Input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  data-testid="login-email-input"
                  className="bg-background/50"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">{t('auth.password')}</Label>
                <Input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="********"
                  required
                  data-testid="login-password-input"
                  className="bg-background/50"
                />
              </div>
              <Button
                type="submit"
                className="w-full"
                disabled={loading}
                data-testid="login-submit-btn"
              >
                {loading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  t('auth.login_btn')
                )}
              </Button>
            </form>
            <p className="text-center text-sm text-muted-foreground mt-6">
              {t('auth.no_account')}{' '}
              <Link to="/register" className="text-primary hover:underline" data-testid="login-register-link">
                {t('auth.register_link')}
              </Link>
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
