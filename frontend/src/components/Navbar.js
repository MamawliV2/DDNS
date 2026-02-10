import { Link, useLocation } from 'react-router-dom';
import { useTheme } from '../contexts/ThemeContext';
import { useLanguage } from '../contexts/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import { Button } from '../components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../components/ui/dropdown-menu';
import { Sun, Moon, Globe, Menu, LogOut, LayoutDashboard, User, Shield } from 'lucide-react';
import { useState } from 'react';

export default function Navbar() {
  const { theme, toggleTheme } = useTheme();
  const { lang, toggleLang, t } = useLanguage();
  const { user, logout } = useAuth();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  const isActive = (path) => location.pathname === path;

  const navLinks = [
    { path: '/', label: t('nav.home') },
    { path: '/#pricing', label: t('nav.pricing'), isHash: true },
  ];

  if (user) {
    navLinks.push({ path: '/dashboard', label: t('nav.dashboard') });
    if (user.role === 'admin') {
      navLinks.push({ path: '/admin', label: t('nav.admin') });
    }
  }

  return (
    <nav
      data-testid="navbar"
      className="fixed top-0 left-0 right-0 z-50 backdrop-blur-xl bg-background/70 border-b border-border/40"
    >
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link
            to="/"
            data-testid="navbar-logo"
            className="flex items-center gap-2 text-lg sm:text-xl font-bold tracking-tight"
            style={{ fontFamily: "'Syne', system-ui, sans-serif" }}
          >
            <img src="/logo.svg" alt="DDNS.LAND" className="w-7 h-7 sm:w-8 sm:h-8 rounded-md" />
            <span>DDNS<span className="text-primary">.LAND</span></span>
          </Link>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                data-testid={`nav-link-${link.path.replace(/[/#]/g, '') || 'home'}`}
                className={`px-3 py-2 text-sm rounded-md transition-colors ${
                  isActive(link.path)
                    ? 'text-foreground bg-muted'
                    : 'text-muted-foreground hover:text-foreground hover:bg-muted/50'
                }`}
              >
                {link.label}
              </Link>
            ))}
          </div>

          {/* Right Section */}
          <div className="flex items-center gap-2">
            {/* Language Toggle */}
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleLang}
              data-testid="lang-toggle"
              className="h-9 w-9"
              title={lang === 'en' ? 'فارسی' : 'English'}
            >
              <Globe className="h-4 w-4" />
            </Button>

            {/* Theme Toggle */}
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleTheme}
              data-testid="theme-toggle"
              className="h-9 w-9"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>

            {/* Auth Buttons */}
            <div className="hidden md:flex items-center gap-2">
              {user ? (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="sm" data-testid="user-menu-trigger" className="gap-2">
                      <User className="h-4 w-4" />
                      <span className="max-w-[120px] truncate text-xs">{user.email}</span>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem asChild>
                      <Link to="/dashboard" className="flex items-center gap-2" data-testid="menu-dashboard">
                        <LayoutDashboard className="h-4 w-4" />
                        {t('nav.dashboard')}
                      </Link>
                    </DropdownMenuItem>
                    {user.role === 'admin' && (
                      <DropdownMenuItem asChild>
                        <Link to="/admin" className="flex items-center gap-2" data-testid="menu-admin">
                          <Shield className="h-4 w-4" />
                          {t('nav.admin')}
                        </Link>
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem
                      onClick={logout}
                      data-testid="menu-logout"
                      className="flex items-center gap-2 text-destructive"
                    >
                      <LogOut className="h-4 w-4" />
                      {t('nav.logout')}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              ) : (
                <>
                  <Link to="/login">
                    <Button variant="ghost" size="sm" data-testid="nav-login-btn">
                      {t('nav.login')}
                    </Button>
                  </Link>
                  <Link to="/register">
                    <Button size="sm" data-testid="nav-register-btn">
                      {t('nav.register')}
                    </Button>
                  </Link>
                </>
              )}
            </div>

            {/* Mobile Menu */}
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden h-9 w-9"
              onClick={() => setMobileOpen(!mobileOpen)}
              data-testid="mobile-menu-btn"
            >
              <Menu className="h-5 w-5" />
            </Button>
          </div>
        </div>

        {/* Mobile Menu Panel */}
        {mobileOpen && (
          <div className="md:hidden pb-4 border-t border-border/40 mt-2 pt-3 space-y-1" data-testid="mobile-menu">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                onClick={() => setMobileOpen(false)}
                className="block px-3 py-2 text-sm rounded-md text-muted-foreground hover:text-foreground hover:bg-muted/50"
              >
                {link.label}
              </Link>
            ))}
            {user ? (
              <>
                <button
                  onClick={() => { logout(); setMobileOpen(false); }}
                  data-testid="mobile-logout"
                  className="block w-full text-start px-3 py-2 text-sm rounded-md text-destructive hover:bg-muted/50"
                >
                  {t('nav.logout')}
                </button>
              </>
            ) : (
              <div className="flex gap-2 px-3 pt-2">
                <Link to="/login" className="flex-1" onClick={() => setMobileOpen(false)}>
                  <Button variant="outline" size="sm" className="w-full">{t('nav.login')}</Button>
                </Link>
                <Link to="/register" className="flex-1" onClick={() => setMobileOpen(false)}>
                  <Button size="sm" className="w-full">{t('nav.register')}</Button>
                </Link>
              </div>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}
