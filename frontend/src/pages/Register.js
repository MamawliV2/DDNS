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
import { UserPlus, Loader2 } from 'lucide-react';

export default function Register() {
  const { t } = useLanguage();
  const { register } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (password !== confirmPassword) {
      toast.error('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      toast.error('Password must be at least 6 characters');
      return;
    }
    setLoading(true);
    try {
      await register(email, password);
      toast.success('Account created successfully!');
      navigate('/dashboard');
    } catch (err) {
      const msg = err.response?.data?.detail || 'Registration failed. Please try again.';
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background grid-bg" data-testid="register-page">
      <Navbar />
      <div className="flex items-center justify-center min-h-screen px-4 pt-16">
        <Card className="w-full max-w-md border-border/60 bg-card/80 backdrop-blur-sm">
          <CardHeader className="text-center pb-2">
            <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mx-auto mb-4">
              <UserPlus className="h-6 w-6 text-primary" />
            </div>
            <CardTitle className="text-xl">{t('auth.register_title')}</CardTitle>
            <CardDescription>{t('auth.register_subtitle')}</CardDescription>
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
                  data-testid="register-email-input"
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
                  data-testid="register-password-input"
                  className="bg-background/50"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirm-password">{t('auth.confirm_password')}</Label>
                <Input
                  id="confirm-password"
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="********"
                  required
                  data-testid="register-confirm-password-input"
                  className="bg-background/50"
                />
              </div>
              <Button
                type="submit"
                className="w-full"
                disabled={loading}
                data-testid="register-submit-btn"
              >
                {loading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  t('auth.register_btn')
                )}
              </Button>
            </form>
            <p className="text-center text-sm text-muted-foreground mt-6">
              {t('auth.has_account')}{' '}
              <Link to="/login" className="text-primary hover:underline" data-testid="register-login-link">
                {t('auth.login_link')}
              </Link>
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
