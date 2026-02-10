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
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '../components/ui/dialog';
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { toast } from 'sonner';
import axios from 'axios';
import {
  Plus, Pencil, Trash2, Loader2, Database, Crown, Server, Send, Globe,
} from 'lucide-react';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;
const TELEGRAM_URL = "https://t.me/DZ_CT";

function StatsCard({ icon: Icon, title, value, subtitle, accentColor }) {
  return (
    <Card className="border-border/60 bg-card/50 backdrop-blur-sm">
      <CardContent className="p-5">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-xs text-muted-foreground mb-1">{title}</p>
            <p className="text-2xl font-bold">{value}</p>
            {subtitle && <p className="text-xs text-muted-foreground mt-1">{subtitle}</p>}
          </div>
          <div className={`w-10 h-10 rounded-md flex items-center justify-center ${accentColor || 'bg-primary/10'}`}>
            <Icon className="h-5 w-5 text-primary" />
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function Dashboard() {
  const { t, lang } = useLanguage();
  const { user, token, refreshUser } = useAuth();
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [userStats, setUserStats] = useState(null);

  // Create dialog
  const [createOpen, setCreateOpen] = useState(false);
  const [createForm, setCreateForm] = useState({ record_type: 'A', name: '', content: '', ttl: 1, proxied: false });
  const [createLoading, setCreateLoading] = useState(false);

  // Edit dialog
  const [editOpen, setEditOpen] = useState(false);
  const [editRecord, setEditRecord] = useState(null);
  const [editForm, setEditForm] = useState({ content: '', ttl: 1, proxied: false });
  const [editLoading, setEditLoading] = useState(false);

  // Delete dialog
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleteRecord, setDeleteRecord] = useState(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const headers = { Authorization: `Bearer ${token}` };

  const fetchRecords = useCallback(async () => {
    try {
      const res = await axios.get(`${API}/dns/records`, { headers });
      setRecords(res.data.records || []);
    } catch {
      toast.error('Failed to load records');
    } finally {
      setLoading(false);
    }
  }, [token]);

  const fetchStats = useCallback(async () => {
    try {
      const res = await axios.get(`${API}/auth/me`, { headers });
      setUserStats(res.data);
    } catch { /* ignore */ }
  }, [token]);

  useEffect(() => {
    fetchRecords();
    fetchStats();
  }, [fetchRecords, fetchStats]);

  const handleCreate = async (e) => {
    e.preventDefault();
    setCreateLoading(true);
    try {
      await axios.post(`${API}/dns/records`, createForm, { headers });
      toast.success('Record created successfully!');
      setCreateOpen(false);
      setCreateForm({ record_type: 'A', name: '', content: '', ttl: 1, proxied: false });
      fetchRecords();
      fetchStats();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to create record');
    } finally {
      setCreateLoading(false);
    }
  };

  const handleEdit = async (e) => {
    e.preventDefault();
    setEditLoading(true);
    try {
      await axios.put(`${API}/dns/records/${editRecord.id}`, editForm, { headers });
      toast.success('Record updated successfully!');
      setEditOpen(false);
      fetchRecords();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to update record');
    } finally {
      setEditLoading(false);
    }
  };

  const handleDelete = async () => {
    setDeleteLoading(true);
    try {
      await axios.delete(`${API}/dns/records/${deleteRecord.id}`, { headers });
      toast.success('Record deleted successfully!');
      setDeleteOpen(false);
      fetchRecords();
      fetchStats();
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to delete record');
    } finally {
      setDeleteLoading(false);
    }
  };

  const openEdit = (record) => {
    setEditRecord(record);
    setEditForm({ content: record.content, ttl: record.ttl || 1, proxied: record.proxied || false });
    setEditOpen(true);
  };

  const openDelete = (record) => {
    setDeleteRecord(record);
    setDeleteOpen(true);
  };

  const getContentPlaceholder = (type) => {
    if (type === 'A') return t('dashboard.content_placeholder_a');
    if (type === 'AAAA') return t('dashboard.content_placeholder_aaaa');
    return t('dashboard.content_placeholder_cname');
  };

  const recordLimit = userStats?.record_limit === -1 ? t('dashboard.stats.unlimited') : userStats?.record_limit ?? 2;
  const canCreate = userStats?.plan !== 'free' || (userStats?.record_count ?? 0) < 2;

  return (
    <div className="min-h-screen bg-background" data-testid="dashboard-page">
      <Navbar />
      <div className="max-w-6xl mx-auto px-4 sm:px-6 pt-24 pb-12">
        {/* Header */}
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-8">
          <div>
            <h1 className="text-2xl sm:text-3xl font-bold" data-testid="dashboard-title">{t('dashboard.title')}</h1>
            <p className="text-sm text-muted-foreground mt-1">
              {user?.email}
            </p>
          </div>
          <div className="flex items-center gap-3">
            {!canCreate && (
              <a href={TELEGRAM_URL} target="_blank" rel="noopener noreferrer">
                <Button variant="outline" size="sm" className="gap-2" data-testid="upgrade-btn">
                  <Send className="h-3.5 w-3.5" />
                  {t('dashboard.upgrade')}
                </Button>
              </a>
            )}
            <Button
              onClick={() => setCreateOpen(true)}
              disabled={!canCreate}
              size="sm"
              className="gap-2"
              data-testid="add-record-btn"
            >
              <Plus className="h-4 w-4" />
              {t('dashboard.add_record')}
            </Button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
          <StatsCard
            icon={Database}
            title={t('dashboard.stats.total_records')}
            value={userStats?.record_count ?? 0}
          />
          <StatsCard
            icon={Server}
            title={t('dashboard.stats.record_limit')}
            value={recordLimit}
          />
          <StatsCard
            icon={Crown}
            title={t('dashboard.stats.plan_type')}
            value={
              <Badge variant={userStats?.plan === 'free' ? 'secondary' : 'default'} className="text-xs">
                {(userStats?.plan || 'free').toUpperCase()}
              </Badge>
            }
          />
        </div>

        {/* Records Table */}
        <Card className="border-border/60 bg-card/50 backdrop-blur-sm">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <Globe className="h-4 w-4" />
              {t('dashboard.records')}
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {loading ? (
              <div className="flex items-center justify-center py-16">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            ) : records.length === 0 ? (
              <div className="text-center py-16 text-muted-foreground" data-testid="no-records-msg">
                <Database className="h-10 w-10 mx-auto mb-3 opacity-40" />
                <p className="text-sm">{t('dashboard.no_records')}</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('dashboard.type')}</TableHead>
                      <TableHead>{t('dashboard.subdomain')}</TableHead>
                      <TableHead>{t('dashboard.content')}</TableHead>
                      <TableHead className="hidden sm:table-cell">{t('dashboard.ttl')}</TableHead>
                      <TableHead className="hidden sm:table-cell">{t('dashboard.proxied')}</TableHead>
                      <TableHead className="text-end">{t('dashboard.actions')}</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {records.map((record) => (
                      <TableRow key={record.id} data-testid={`record-row-${record.id}`}>
                        <TableCell>
                          <Badge variant="outline" className="font-mono text-[10px]">
                            {record.record_type}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <span className="font-mono text-sm">{record.name}</span>
                          <span className="text-muted-foreground text-xs">.ddns.land</span>
                        </TableCell>
                        <TableCell>
                          <span className="font-mono text-sm">{record.content}</span>
                        </TableCell>
                        <TableCell className="hidden sm:table-cell font-mono text-xs">
                          {record.ttl === 1 ? 'Auto' : record.ttl}
                        </TableCell>
                        <TableCell className="hidden sm:table-cell">
                          <Badge variant={record.proxied ? 'default' : 'outline'} className="text-[10px]">
                            {record.proxied ? 'ON' : 'OFF'}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center justify-end gap-1">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8"
                              onClick={() => openEdit(record)}
                              data-testid={`edit-record-${record.id}`}
                            >
                              <Pencil className="h-3.5 w-3.5" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 text-destructive hover:text-destructive"
                              onClick={() => openDelete(record)}
                              data-testid={`delete-record-${record.id}`}
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
            )}
          </CardContent>
        </Card>
      </div>

      {/* Create Record Dialog */}
      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent data-testid="create-record-dialog">
          <DialogHeader>
            <DialogTitle>{t('dashboard.create_title')}</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleCreate} className="space-y-4">
            <div className="space-y-2">
              <Label>{t('dashboard.record_type')}</Label>
              <Select
                value={createForm.record_type}
                onValueChange={(val) => setCreateForm({ ...createForm, record_type: val, content: '' })}
              >
                <SelectTrigger data-testid="create-type-select">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="A">A (IPv4)</SelectItem>
                  <SelectItem value="AAAA">AAAA (IPv6)</SelectItem>
                  <SelectItem value="CNAME">CNAME</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>{t('dashboard.subdomain')}</Label>
              <div className="flex items-center gap-2">
                <Input
                  value={createForm.name}
                  onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })}
                  placeholder={t('dashboard.subdomain_placeholder')}
                  required
                  data-testid="create-name-input"
                  className="bg-background/50"
                  dir="ltr"
                />
                <span className="text-sm text-muted-foreground whitespace-nowrap font-mono">.ddns.land</span>
              </div>
            </div>
            <div className="space-y-2">
              <Label>{t('dashboard.content')}</Label>
              <Input
                value={createForm.content}
                onChange={(e) => setCreateForm({ ...createForm, content: e.target.value })}
                placeholder={getContentPlaceholder(createForm.record_type)}
                required
                data-testid="create-content-input"
                className="bg-background/50 font-mono"
                dir="ltr"
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>{t('dashboard.proxied')}</Label>
              <Switch
                checked={createForm.proxied}
                onCheckedChange={(val) => setCreateForm({ ...createForm, proxied: val })}
                data-testid="create-proxied-switch"
              />
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setCreateOpen(false)}>
                {t('dashboard.cancel')}
              </Button>
              <Button type="submit" disabled={createLoading} data-testid="create-submit-btn">
                {createLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('dashboard.create')}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Edit Record Dialog */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent data-testid="edit-record-dialog">
          <DialogHeader>
            <DialogTitle>{t('dashboard.edit_title')}</DialogTitle>
          </DialogHeader>
          <form onSubmit={handleEdit} className="space-y-4">
            {editRecord && (
              <div className="rounded-md bg-muted/50 p-3">
                <p className="text-xs text-muted-foreground mb-1">{t('dashboard.subdomain')}</p>
                <p className="font-mono text-sm">
                  <Badge variant="outline" className="me-2 text-[10px]">{editRecord.record_type}</Badge>
                  {editRecord.name}.ddns.land
                </p>
              </div>
            )}
            <div className="space-y-2">
              <Label>{t('dashboard.content')}</Label>
              <Input
                value={editForm.content}
                onChange={(e) => setEditForm({ ...editForm, content: e.target.value })}
                placeholder={editRecord ? getContentPlaceholder(editRecord.record_type) : ''}
                required
                data-testid="edit-content-input"
                className="bg-background/50 font-mono"
                dir="ltr"
              />
            </div>
            <div className="flex items-center justify-between">
              <Label>{t('dashboard.proxied')}</Label>
              <Switch
                checked={editForm.proxied}
                onCheckedChange={(val) => setEditForm({ ...editForm, proxied: val })}
                data-testid="edit-proxied-switch"
              />
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setEditOpen(false)}>
                {t('dashboard.cancel')}
              </Button>
              <Button type="submit" disabled={editLoading} data-testid="edit-submit-btn">
                {editLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('dashboard.save')}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent data-testid="delete-record-dialog">
          <AlertDialogHeader>
            <AlertDialogTitle>{t('dashboard.delete_title')}</AlertDialogTitle>
            <AlertDialogDescription>
              {t('dashboard.delete_confirm')}
              {deleteRecord && (
                <span className="block mt-2 font-mono text-xs">
                  {deleteRecord.name}.ddns.land ({deleteRecord.record_type})
                </span>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel data-testid="delete-cancel-btn">{t('dashboard.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              disabled={deleteLoading}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              data-testid="delete-confirm-btn"
            >
              {deleteLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('dashboard.delete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
