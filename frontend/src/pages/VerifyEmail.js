import { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from '../components/Navbar';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '../components/ui/card';
import { toast } from 'sonner';
import { ShieldCheck, Loader2, RotateCcw } from 'lucide-react';

export default function VerifyEmail() {
  const { t } = useLanguage();
  const { verifyEmail, resendCode } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || '';

  const [digits, setDigits] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const inputRefs = useRef([]);

  useEffect(() => {
    if (!email) {
      navigate('/register', { replace: true });
    }
  }, [email, navigate]);

  useEffect(() => {
    if (cooldown > 0) {
      const timer = setTimeout(() => setCooldown(cooldown - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [cooldown]);

  const handleChange = (index, value) => {
    if (!/^\d*$/.test(value)) return;
    const newDigits = [...digits];
    newDigits[index] = value.slice(-1);
    setDigits(newDigits);

    if (value && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !digits[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handlePaste = (e) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (pasted.length === 6) {
      const newDigits = pasted.split('');
      setDigits(newDigits);
      inputRefs.current[5]?.focus();
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const code = digits.join('');
    if (code.length !== 6) {
      toast.error(t('auth.verify_enter_code'));
      return;
    }
    setLoading(true);
    try {
      await verifyEmail(email, code);
      toast.success(t('auth.verify_success'));
      navigate('/dashboard', { replace: true });
    } catch (err) {
      const detail = err.response?.data?.detail || 'Verification failed';
      toast.error(detail);
      setDigits(['', '', '', '', '', '']);
      inputRefs.current[0]?.focus();
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    setResendLoading(true);
    try {
      await resendCode(email);
      toast.success(t('auth.verify_resent'));
      setCooldown(60);
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to resend code');
    } finally {
      setResendLoading(false);
    }
  };

  const code = digits.join('');

  return (
    <div className="min-h-screen bg-background grid-bg" data-testid="verify-page">
      <Navbar />
      <div className="flex items-center justify-center min-h-screen px-4 pt-16">
        <Card className="w-full max-w-md border-border/60 bg-card/80 backdrop-blur-sm">
          <CardHeader className="text-center pb-2">
            <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mx-auto mb-4">
              <ShieldCheck className="h-6 w-6 text-primary" />
            </div>
            <CardTitle className="text-xl">{t('auth.verify_title')}</CardTitle>
            <CardDescription>
              {t('auth.verify_subtitle')}
              <span className="block font-mono text-sm text-foreground mt-1">{email}</span>
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="flex justify-center gap-2" dir="ltr" onPaste={handlePaste}>
                {digits.map((digit, i) => (
                  <Input
                    key={i}
                    ref={el => inputRefs.current[i] = el}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={digit}
                    onChange={(e) => handleChange(i, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(i, e)}
                    className="w-12 h-14 text-center text-xl font-mono font-bold bg-background/50"
                    data-testid={`verify-digit-${i}`}
                    autoFocus={i === 0}
                  />
                ))}
              </div>

              <Button
                type="submit"
                className="w-full"
                disabled={loading || code.length !== 6}
                data-testid="verify-submit-btn"
              >
                {loading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  t('auth.verify_btn')
                )}
              </Button>
            </form>

            <div className="text-center mt-6">
              <p className="text-sm text-muted-foreground mb-2">{t('auth.verify_no_code')}</p>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleResend}
                disabled={resendLoading || cooldown > 0}
                className="gap-2"
                data-testid="verify-resend-btn"
              >
                <RotateCcw className="h-3.5 w-3.5" />
                {cooldown > 0
                  ? `${t('auth.verify_resend')} (${cooldown}s)`
                  : t('auth.verify_resend')
                }
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
