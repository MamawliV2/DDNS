import { useState, useEffect, useCallback } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import Navbar from '../components/Navbar';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { Switch } from '../components/ui/switch';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '../components/ui/alert-dialog';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '../components/ui/dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../components/ui/dropdown-menu';
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '../components/ui/tabs';
import { toast } from 'sonner';
import axios from 'axios';
import {
  Users, Database, Crown, Loader2, Trash2, MoreVertical, Shield, Star, UserX, Eye, Globe, X, Plus,
} from 'lucide-react';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

function AdminStatsCard({ icon: Icon, title, value, color }) {
  return (
    <Card className="border-border/60 bg-card/50 backdrop-blur-sm">
      <CardContent className="p-5">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-xs text-muted-foreground mb-1">{title}</p>
            <div className="text-2xl font-bold">{value}</div>
          </div>
          <div className={`w-10 h-10 rounded-md flex items-center justify-center ${color || 'bg-primary/10'}`}>
            <Icon className="h-5 w-5 text-primary" />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function Admin() {
  const { t } = useLanguage();
  const { token } = useAuth();
  const [users, setUsers] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteUser, setDeleteUser] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Records viewer
  const [recordsOpen, setRecordsOpen] = useState(false);
  const [recordsUser, setRecordsUser] = useState(null);
  const [userRecords, setUserRecords] = useState([]);
  const [recordsLoading, setRecordsLoading] = useState(false);
  const [deleteRecordOpen, setDeleteRecordOpen] = useState(false);
  const [deleteRecordItem, setDeleteRecordItem] = useState(null);
  const [deleteRecordLoading, setDeleteRecordLoading] = useState(false);

  // Domains
  const [domains, setDomains] = useState([]);
  const [domainsLoading, setDomainsLoading] = useState(false);
  const [addDomainOpen, setAddDomainOpen] = useState(false);
  const [domainForm, setDomainForm] = useState({ name: '', zone_id: '' });
  const [addDomainLoading, setAddDomainLoading] = useState(false);
  const [deleteDomainOpen, setDeleteDomainOpen] = useState(false);
  const [deleteDomainItem, setDeleteDomainItem] = useState(null);
  const [deleteDomainLoading, setDeleteDomainLoading] = useState(false);

  const getHeaders = useCallback(() => ({ Authorization: `Bearer ${token}` }), [token]);

  const fetchData = useCallback(async () => {
    try {
      const [usersRes, statsRes] = await Promise.all([
        axios.get(`${API}/admin/users`, { headers: getHeaders() }),
        axios.get(`${API}/admin/stats`, { headers: getHeaders() }),
      ]);
      setUsers(usersRes.data.users || []);
      setStats(statsRes.data);
    } catch (err) {
      if (err.response?.status === 403) {
        toast.error('Admin access required');
      } else {
        toast.error('Failed to load admin data');
      }
    } finally {
      setLoading(false);
    }
  }, [getHeaders]);

  const fetchDomains = useCallback(async () => {
    setDomainsLoading(true);
    try {
      const res = await axios.get(`${API}/admin/domains`, { headers: getHeaders() });
      setDomains(res.data.domains || []);
    } catch {
      toast.error('Failed to load domains');
    } finally {
      setDomainsLoading(false);
    }
  }, [getHeaders]);

  useEffect(() => {
    fetchData();
    fetchDomains();
  }, [fetchData, fetchDomains]);

  const handleChangePlan = async (userId, plan) => {
    setActionLoading(true);
    try {
      await axios.put(`${API}/admin/users/${userId}/plan`, { plan }, { headers: getHeaders() });
      toast.success(`Plan updated to ${plan}`);
      fetchData();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to update plan');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteUser = async () => {
    if (!deleteUser) return;
    setActionLoading(true);
    try {
      await axios.delete(`${API}/admin/users/${deleteUser.id}`, { headers: getHeaders() });
      toast.success('User deleted');
      setDeleteOpen(false);
      fetchData();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to delete user');
    } finally {
      setActionLoading(false);
    }
  };

  const openUserRecords = async (user) => {
    setRecordsUser(user);
    setRecordsOpen(true);
    setRecordsLoading(true);
    try {
      const res = await axios.get(`${API}/admin/users/${user.id}/records`, { headers: getHeaders() });
      setUserRecords(res.data.records || []);
    } catch {
      toast.error('Failed to load user records');
    } finally {
      setRecordsLoading(false);
    }
  };

  const handleDeleteRecord = async () => {
    if (!deleteRecordItem) return;
    setDeleteRecordLoading(true);
    try {
      await axios.delete(`${API}/admin/records/${deleteRecordItem.id}`, { headers: getHeaders() });
      toast.success('Record deleted');
      setDeleteRecordOpen(false);
      setDeleteRecordItem(null);
      setUserRecords(prev => prev.filter(r => r.id !== deleteRecordItem.id));
      fetchData();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to delete record');
    } finally {
      setDeleteRecordLoading(false);
    }
  };

  // Domain handlers
  const handleAddDomain = async (e) => {
    e.preventDefault();
    setAddDomainLoading(true);
    try {
      await axios.post(`${API}/admin/domains`, domainForm, { headers: getHeaders() });
      toast.success('Domain added!');
      setAddDomainOpen(false);
      setDomainForm({ name: '', zone_id: '' });
      fetchDomains();
      fetchData();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to add domain');
    } finally {
      setAddDomainLoading(false);
    }
  };

  const handleToggleDomain = async (domain) => {
    try {
      await axios.put(`${API}/admin/domains/${domain.id}`, { active: !domain.active }, { headers: getHeaders() });
      toast.success(domain.active ? 'Domain deactivated' : 'Domain activated');
      fetchDomains();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to update domain');
    }
  };

  const handleDeleteDomain = async () => {
    if (!deleteDomainItem) return;
    setDeleteDomainLoading(true);
    try {
      await axios.delete(`${API}/admin/domains/${deleteDomainItem.id}`, { headers: getHeaders() });
      toast.success('Domain deleted');
      setDeleteDomainOpen(false);
      setDeleteDomainItem(null);
      fetchDomains();
      fetchData();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to delete domain');
    } finally {
      setDeleteDomainLoading(false);
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background">
        <Navbar />
        <div className="flex items-center justify-center min-h-screen">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background" data-testid="admin-page">
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 pt-24 pb-12">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <Shield className="h-6 w-6 text-primary" />
            <h1 className="text-2xl sm:text-3xl font-bold" data-testid="admin-title">{t('admin.title')}</h1>
          </div>
        </div>

        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
            <AdminStatsCard icon={Users} title={t('admin.total_users')} value={stats.total_users} />
            <AdminStatsCard icon={Database} title={t('admin.total_records')} value={stats.total_records} />
            <AdminStatsCard icon={UserX} title={t('admin.free_users')} value={stats.free_users} />
            <AdminStatsCard icon={Crown} title={t('admin.premium_users')} value={stats.premium_users} />
            <AdminStatsCard icon={Globe} title={t('admin.total_domains')} value={stats.total_domains} />
            <AdminStatsCard icon={Globe} title={t('admin.active_domains')} value={stats.active_domains} />
          </div>
        )}

        {/* Tabs */}
        <Tabs defaultValue="users" className="space-y-4">
          <TabsList data-testid="admin-tabs">
            <TabsTrigger value="users" data-testid="admin-tab-users">
              <Users className="h-4 w-4 me-2" />
              {t('admin.users')}
            </TabsTrigger>
            <TabsTrigger value="domains" data-testid="admin-tab-domains">
              <Globe className="h-4 w-4 me-2" />
              {t('admin.domains')}
            </TabsTrigger>
          </TabsList>

          {/* Users Tab */}
          <TabsContent value="users">
            <Card className="border-border/60 bg-card/50 backdrop-blur-sm">
              <CardHeader className="pb-3">
                <CardTitle className="text-base flex items-center gap-2">
                  <Users className="h-4 w-4" />
                  {t('admin.users')}
                </CardTitle>
              </CardHeader>
              <CardContent className="p-0">
                {users.length === 0 ? (
                  <div className="text-center py-16 text-muted-foreground" data-testid="no-users-msg">
                    <Users className="h-10 w-10 mx-auto mb-3 opacity-40" />
                    <p className="text-sm">{t('admin.no_users')}</p>
                  </div>
                ) : (
                  <>
                    {/* Mobile Card View */}
                    <div className="block sm:hidden p-4 space-y-3">
                      {users.map((u) => (
                        <div key={u.id} data-testid={`admin-user-card-${u.id}`} className="rounded-lg border border-border/60 p-4 space-y-3">
                          <div className="flex items-center justify-between">
                            <span className="text-sm font-mono truncate max-w-[200px]">{u.email}</span>
                            <div className="flex items-center gap-1 shrink-0">
                              <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openUserRecords(u)} data-testid={`view-records-mobile-${u.id}`}>
                                <Eye className="h-4 w-4" />
                              </Button>
                              {u.role !== 'admin' && (
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button variant="ghost" size="icon" className="h-8 w-8" data-testid={`admin-actions-mobile-${u.id}`}>
                                    <MoreVertical className="h-4 w-4" />
                                  </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end">
                                  {u.plan === 'free' ? (
                                    <DropdownMenuItem onClick={() => handleChangePlan(u.id, 'premium')}>
                                      <Crown className="h-4 w-4 me-2" />{t('admin.set_premium')}
                                    </DropdownMenuItem>
                                  ) : (
                                    <DropdownMenuItem onClick={() => handleChangePlan(u.id, 'free')}>
                                      <UserX className="h-4 w-4 me-2" />{t('admin.set_free')}
                                    </DropdownMenuItem>
                                  )}
                                  <DropdownMenuItem onClick={() => { setDeleteUser(u); setDeleteOpen(true); }} className="text-destructive">
                                    <Trash2 className="h-4 w-4 me-2" />{t('admin.delete_user')}
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                              )}
                            </div>
                          </div>
                          <div className="flex items-center gap-2 flex-wrap">
                            <Badge variant={u.plan === 'premium' ? 'default' : 'secondary'} className="text-[10px]">
                              {u.plan === 'premium' ? 'Premium' : 'Free'}
                            </Badge>
                            <Badge variant={u.role === 'admin' ? 'destructive' : 'outline'} className="text-[10px]">
                              {u.role === 'admin' ? 'Admin' : 'User'}
                            </Badge>
                            <span className="text-xs text-muted-foreground">{u.record_count || 0} {t('admin.records')}</span>
                          </div>
                          <p className="text-xs text-muted-foreground">{formatDate(u.created_at)}</p>
                        </div>
                      ))}
                    </div>
                    {/* Desktop Table View */}
                    <div className="hidden sm:block overflow-x-auto">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>{t('admin.email')}</TableHead>
                          <TableHead>{t('admin.plan')}</TableHead>
                          <TableHead>{t('admin.role')}</TableHead>
                          <TableHead className="hidden sm:table-cell">{t('admin.records')}</TableHead>
                          <TableHead className="hidden sm:table-cell">{t('admin.joined')}</TableHead>
                          <TableHead className="text-end">{t('admin.actions')}</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {users.map((u) => (
                          <TableRow key={u.id} data-testid={`admin-user-row-${u.id}`}>
                            <TableCell>
                              <span className="text-sm font-mono">{u.email}</span>
                            </TableCell>
                            <TableCell>
                              <Badge variant={u.plan === 'premium' ? 'default' : 'secondary'} className="text-[10px]">
                                {u.plan === 'premium' ? (<><Star className="h-3 w-3 me-1" /> Premium</>) : 'Free'}
                              </Badge>
                            </TableCell>
                            <TableCell>
                              <Badge variant={u.role === 'admin' ? 'destructive' : 'outline'} className="text-[10px]">
                                {u.role === 'admin' ? (<><Shield className="h-3 w-3 me-1" /> Admin</>) : 'User'}
                              </Badge>
                            </TableCell>
                            <TableCell className="hidden sm:table-cell font-mono text-sm">
                              {u.record_count || 0}
                            </TableCell>
                            <TableCell className="hidden sm:table-cell text-xs text-muted-foreground">
                              {formatDate(u.created_at)}
                            </TableCell>
                            <TableCell>
                              <div className="flex items-center justify-end gap-1">
                                <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openUserRecords(u)} data-testid={`view-records-${u.id}`}>
                                  <Eye className="h-4 w-4" />
                                </Button>
                                {u.role !== 'admin' && (
                                  <DropdownMenu>
                                    <DropdownMenuTrigger asChild>
                                      <Button variant="ghost" size="icon" className="h-8 w-8" data-testid={`admin-actions-${u.id}`}>
                                        <MoreVertical className="h-4 w-4" />
                                      </Button>
                                    </DropdownMenuTrigger>
                                    <DropdownMenuContent align="end">
                                      {u.plan === 'free' ? (
                                        <DropdownMenuItem onClick={() => handleChangePlan(u.id, 'premium')} data-testid={`set-premium-${u.id}`}>
                                          <Crown className="h-4 w-4 me-2" />{t('admin.set_premium')}
                                        </DropdownMenuItem>
                                      ) : (
                                        <DropdownMenuItem onClick={() => handleChangePlan(u.id, 'free')} data-testid={`set-free-${u.id}`}>
                                          <UserX className="h-4 w-4 me-2" />{t('admin.set_free')}
                                        </DropdownMenuItem>
                                      )}
                                      <DropdownMenuItem onClick={() => { setDeleteUser(u); setDeleteOpen(true); }} className="text-destructive" data-testid={`delete-user-${u.id}`}>
                                        <Trash2 className="h-4 w-4 me-2" />{t('admin.delete_user')}
                                      </DropdownMenuItem>
                                    </DropdownMenuContent>
                                  </DropdownMenu>
                                )}
                              </div>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* Domains Tab */}
          <TabsContent value="domains">
            <Card className="border-border/60 bg-card/50 backdrop-blur-sm">
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-base flex items-center gap-2">
                    <Globe className="h-4 w-4" />
                    {t('admin.domains')}
                  </CardTitle>
                  <Button size="sm" className="gap-2" onClick={() => setAddDomainOpen(true)} data-testid="add-domain-btn">
                    <Plus className="h-4 w-4" />
                    {t('admin.add_domain')}
                  </Button>
                </div>
              </CardHeader>
              <CardContent className="p-0">
                {domainsLoading ? (
                  <div className="flex items-center justify-center py-16">
                    <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                  </div>
                ) : domains.length === 0 ? (
                  <div className="text-center py-16 text-muted-foreground" data-testid="no-domains-msg">
                    <Globe className="h-10 w-10 mx-auto mb-3 opacity-40" />
                    <p className="text-sm">{t('admin.no_domains')}</p>
                  </div>
                ) : (
                  <>
                    {/* Mobile Card View */}
                    <div className="block sm:hidden p-4 space-y-3">
                      {domains.map((d) => (
                        <div key={d.id} data-testid={`domain-card-${d.id}`} className="rounded-lg border border-border/60 p-4 space-y-3">
                          <div className="flex items-center justify-between">
                            <span className="font-mono text-sm font-medium">{d.name}</span>
                            <div className="flex items-center gap-2">
                              <Switch
                                checked={d.active}
                                onCheckedChange={() => handleToggleDomain(d)}
                                data-testid={`toggle-domain-mobile-${d.id}`}
                              />
                              <Button
                                variant="ghost"
                                size="icon"
                                className="h-8 w-8 text-destructive hover:text-destructive"
                                onClick={() => { setDeleteDomainItem(d); setDeleteDomainOpen(true); }}
                                data-testid={`delete-domain-mobile-${d.id}`}
                              >
                                <Trash2 className="h-3.5 w-3.5" />
                              </Button>
                            </div>
                          </div>
                          <div className="font-mono text-xs text-muted-foreground bg-muted/30 rounded px-3 py-2 break-all" dir="ltr">
                            Zone: {d.zone_id}
                          </div>
                          <div className="flex items-center gap-4 text-xs text-muted-foreground">
                            <Badge variant={d.active ? 'default' : 'secondary'} className="text-[10px]">
                              {d.active ? t('admin.domain_active') : t('admin.domain_inactive')}
                            </Badge>
                            <span>{d.record_count || 0} {t('admin.records')}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                    {/* Desktop Table View */}
                    <div className="hidden sm:block overflow-x-auto">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>{t('admin.domain_name')}</TableHead>
                          <TableHead>{t('admin.zone_id')}</TableHead>
                          <TableHead>{t('admin.records')}</TableHead>
                          <TableHead>{t('admin.domain_active')}</TableHead>
                          <TableHead className="text-end">{t('admin.actions')}</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {domains.map((d) => (
                          <TableRow key={d.id} data-testid={`domain-row-${d.id}`}>
                            <TableCell>
                              <span className="font-mono text-sm font-medium">{d.name}</span>
                            </TableCell>
                            <TableCell>
                              <span className="font-mono text-xs text-muted-foreground">{d.zone_id.substring(0, 12)}...</span>
                            </TableCell>
                            <TableCell className="font-mono text-sm">
                              {d.record_count || 0}
                            </TableCell>
                            <TableCell>
                              <Switch
                                checked={d.active}
                                onCheckedChange={() => handleToggleDomain(d)}
                                data-testid={`toggle-domain-${d.id}`}
                              />
                            </TableCell>
                            <TableCell>
                              <div className="flex items-center justify-end">
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 text-destructive hover:text-destructive"
                                  onClick={() => { setDeleteDomainItem(d); setDeleteDomainOpen(true); }}
                                  data-testid={`delete-domain-${d.id}`}
                                >
                                  <Trash2 className="h-3.5 w-3.5" />
                                </Button>
                              </div>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>

      {/* Add Domain Dialog */}
      <Dialog open={addDomainOpen} onOpenChange={setAddDomainOpen}>
        <DialogContent data-testid="add-domain-dialog">
          <DialogHeader>
            <DialogTitle>{t('admin.add_domain')}</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleAddDomain} className="space-y-4">
            <div className="space-y-2">
              <Label>{t('admin.domain_name')}</Label>
              <Input
                value={domainForm.name}
                onChange={(e) => setDomainForm({ ...domainForm, name: e.target.value })}
                placeholder={t('admin.domain_name_placeholder')}
                required
                data-testid="domain-name-input"
                className="bg-background/50 font-mono"
                dir="ltr"
              />
            </div>
            <div className="space-y-2">
              <Label>{t('admin.zone_id')}</Label>
              <Input
                value={domainForm.zone_id}
                onChange={(e) => setDomainForm({ ...domainForm, zone_id: e.target.value })}
                placeholder={t('admin.zone_id_placeholder')}
                required
                data-testid="domain-zone-input"
                className="bg-background/50 font-mono"
                dir="ltr"
              />
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setAddDomainOpen(false)}>
                {t('dashboard.cancel')}
              </Button>
              <Button type="submit" disabled={addDomainLoading} data-testid="domain-submit-btn">
                {addDomainLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('admin.add_domain')}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete User Dialog */}
      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent data-testid="delete-user-dialog">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('admin.delete_user')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('admin.delete_confirm')}
              {deleteUser && (
                <span className="block mt-2 font-mono text-xs">{deleteUser.email}</span>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('dashboard.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteUser}
              disabled={actionLoading}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              data-testid="confirm-delete-user-btn"
            >
              {actionLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('admin.delete_user')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* View User Records Dialog */}
      <Dialog open={recordsOpen} onOpenChange={setRecordsOpen}>
        <DialogContent className="max-w-2xl max-h-[80vh] overflow-hidden flex flex-col" data-testid="view-records-dialog">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Globe className="h-5 w-5" />
              {t('admin.view_records')}
            </DialogTitle>
            {recordsUser && (
              <p className="text-sm text-muted-foreground font-mono">{recordsUser.email}</p>
            )}
          </DialogHeader>
          <div className="overflow-y-auto flex-1">
            {recordsLoading ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            ) : userRecords.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground">
                <Database className="h-8 w-8 mx-auto mb-2 opacity-40" />
                <p className="text-sm">{t('admin.no_records')}</p>
              </div>
            ) : (
              <div className="space-y-3 p-1">
                {userRecords.map((record) => (
                  <div key={record.id} data-testid={`admin-record-${record.id}`} className="rounded-lg border border-border/60 p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <Badge variant="outline" className="font-mono text-[10px]">{record.record_type}</Badge>
                        <span className="font-mono text-sm font-medium">{record.name}<span className="text-muted-foreground">.{record.domain_name || 'dnslab.biz'}</span></span>
                      </div>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 text-destructive hover:text-destructive"
                        onClick={() => { setDeleteRecordItem(record); setDeleteRecordOpen(true); }}
                        data-testid={`admin-delete-record-${record.id}`}
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </Button>
                    </div>
                    <div className="font-mono text-xs text-muted-foreground bg-muted/30 rounded px-3 py-2 break-all" dir="ltr">
                      {record.content}
                    </div>
                    <div className="flex items-center gap-4 mt-2 text-xs text-muted-foreground">
                      <span>TTL: {record.ttl === 1 ? 'Auto' : record.ttl}</span>
                      <Badge variant={record.proxied ? 'default' : 'outline'} className="text-[10px]">
                        {record.proxied ? 'Proxied' : 'DNS Only'}
                      </Badge>
                      {record.created_at && <span>{formatDate(record.created_at)}</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>

      {/* Delete Record Confirmation */}
      <AlertDialog open={deleteRecordOpen} onOpenChange={setDeleteRecordOpen}>
        <AlertDialogContent data-testid="admin-delete-record-dialog">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('admin.delete_record')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('admin.delete_record_confirm')}
              {deleteRecordItem && (
                <span className="block mt-2 font-mono text-xs">
                  {deleteRecordItem.name}.{deleteRecordItem.domain_name || 'dnslab.biz'} ({deleteRecordItem.record_type}) &rarr; {deleteRecordItem.content}
                </span>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('dashboard.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteRecord}
              disabled={deleteRecordLoading}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              data-testid="admin-confirm-delete-record-btn"
            >
              {deleteRecordLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('dashboard.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Delete Domain Confirmation */}
      <AlertDialog open={deleteDomainOpen} onOpenChange={setDeleteDomainOpen}>
        <AlertDialogContent data-testid="delete-domain-dialog">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('admin.delete_domain')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('admin.delete_domain_confirm')}
              {deleteDomainItem && (
                <span className="block mt-2 font-mono text-xs">{deleteDomainItem.name}</span>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('dashboard.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteDomain}
              disabled={deleteDomainLoading}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              data-testid="confirm-delete-domain-btn"
            >
              {deleteDomainLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('admin.delete_domain')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
